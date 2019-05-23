#!/usr/bin/env -i SHELL=/bin/sh COMMAND_MODE=unix2003 LANG=C LC_ALL=C /bin/ksh
 set -e
 set -u
 set -x

proj_version=$(date +%Y%m%d)
proj_root=$(cd "$(dirname "${0}")" && pwd)
srcdir="${proj_root}"/src
dstroot=/tmp/local
prefix=${dstroot}
libdir=${dstroot}/lib
bindir=${prefix}/libexec/bin
incdir=${prefix}/libexec/include
builddir=/tmp/_build

ncpu=$(($(/usr/sbin/sysctl -n hw.logicalcpu) + 1))

save_time()
(
    printf '%s\t%s\n' "$(date)" "${*}" >>${builddir}/build.log
)

make()
(
    command make -j ${ncpu} "${@}"
)


set -a
    LANG=ja_JP.UTF-8
    LC_ALL=ja_JP.UTF-8

    PATH="/dev/null"
    PATH+=":${bindir}"
    PATH+=":/opt/local/libexec/gnubin"
#   PATH+=":/opt/local/libexec/coreutils"
#   PATH+=":$(/usr/bin/xcode-select -print-path)/usr/bin"
    PATH+=":$(/usr/bin/getconf PATH)"

#   MACOSX_DEPLOYMENT_TARGET=$(xcrun --show-sdk-version)
    MACOSX_DEPLOYMENT_TARGET=10.11
    SDKROOT=$(xcrun --show-sdk-path)

        CC="/opt/local/bin/ccache clang"
       CPP="/opt/local/bin/ccache clang -E"
       CXX="/opt/local/bin/ccache clang++"
    CXXCPP="/opt/local/bin/ccache clang++ -E"
    CFLAGS=
#   CFLAGS+=" -arch i386"
#   CFLAGS+=" -arch x86_64"
    CFLAGS+=" -O2"
    CFLAGS+=" -std=gnu89"
    CFLAGS+=" -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    CXXFLAGS=
#   CXXFLAGS+=" -arch i386"
#   CXXFLAGS+=" -arch x86_64"
    CXXFLAGS+=" -O2"
    CXXFLAGS+=" -stdlib=libc++"
    CPPFLAGS=
    CPPFLAGS+=" -isysroot ${SDKROOT}"
    CPPFLAGS+=" -I${incdir}"
    LDFLAGS=
    LDFLAGS+=" -Wl,-syslibroot,${SDKROOT}"
    LDFLAGS+=" -Wl,-macosx_version_min,${MACOSX_DEPLOYMENT_TARGET}"
    LDFLAGS+=" -Wl,-headerpad_max_install_names"
#   LDFLAGS+=" -Z"
    LDFLAGS+=" -L${libdir}"
#   LDFLAGS+=" -L/usr/lib"
#   LDFLAGS+=" -F/System/Library/Frameworks"

#   PKG_CONFIG=/opt/local/bin/pkg-config
    PKG_CONFIG_LIBDIR=
    PKG_CONFIG_LIBDIR+=":${libdir}/pkgconfig"
    PKG_CONFIG_LIBDIR+=":/usr/lib/pkgconfig"
    PKG_CONFIG_PATH=
set +a

init()
{
    test ! -d ${dstroot} \
    || rm -rf ${dstroot}
    mkdir -p  ${dstroot}

    test ! -d ${builddir} \
    || rm -rf ${builddir}
    mkdir -p  ${builddir}

    test -e "${srcdir}"/sdk.tar.bz2 || ./build-dep.sh
    tar xf  "${srcdir}"/sdk.tar.bz2 \
        --exclude '*/share' \
        --exclude '*/cmake' \
        --exclude '*.a' \
        --exclude '*.la' \
        -C ${dstroot}

}

build_wine()
(
    name=wine
#   rsync -a --delete "${srcdir}"/${name}/        ${builddir}/${name}/
    rsync -a --delete "${srcdir}"/${name}-stable/ ${builddir}/${name}/
    cd ${builddir}/${name}

    patch_wine

    args=(
        --prefix=${prefix}
        --with-cms
        --with-freetype
        --with-png
        --with-x
        --x-inc=/opt/X11/include
        --x-lib=/opt/X11/lib
    )

    ## 64-bit (first)
    test ! -d ${builddir}/${name}/m64 \
    || rm -rf ${builddir}/${name}/m64
    mkdir -p  ${builddir}/${name}/m64
    cd        ${builddir}/${name}/m64
    ../configure "${args[@]}" --libdir=${libdir} --enable-win64
    make dlldir=${libdir}/wine64

    ## 32-bit
    test ! -d ${builddir}/${name}/m32 \
    || rm -rf ${builddir}/${name}/m32
    mkdir -p  ${builddir}/${name}/m32
    cd        ${builddir}/${name}/m32
    ../configure "${args[@]}" --with-win64=../m64
    make
    make install

    ## 64-bit (second)
    cd        ${builddir}/${name}/m64
    make install dlldir=${libdir}/wine64

    ## UNIVERSAL
    lipo -create \
        -arch i386   ${builddir}/${name}/m32/libs/wine/libwine.1.0.dylib \
        -arch x86_64 ${builddir}/${name}/m64/libs/wine/libwine.1.0.dylib \
        -output                              ${libdir}/libwine.1.0.dylib

)

patch_wine()
(
    set -- "${proj_root}"/patch/wine___*.diff
    for f
    do
        test -e "${f}" || continue
        patch -Np1 <"${f}"
    done
)

change_install_name()
(
    is_external_lib()
    (
        case ${1} in
        /Library/*      |\
        /System/*       |\
        /usr/lib/*      |\
        /usr/local/lib/*)
            return 1
        ;;
        @rpath/*)
            return 1
        ;;
        /usr/X11/lib/*|\
        /opt/X11/lib/*)
            return 1
        ;;
        esac
        return 0
    )

    change_id()
    (
        obj=${1}
        save_IFS=${IFS} IFS=$'\n'
        set -- $(otool -D "${obj}")
        IFS=${save_IFS}
        shift || return 0 # truncate otool header
        is_external_lib "${1}" || return 0
        (
            echo
            set -x
            install_name_tool -id @rpath/"${1##*/}" "${obj}"
        )
    )

    change_link()
    (
        obj=${1}
        set -- $(otool -L "${obj}" | grep -v "$(otool -D "${obj}")" | awk '{ print $1 }')
        for f
        do
            is_external_lib "${f}" || continue
            (
                echo
                set -x
                install_name_tool -change "${f}" @rpath/"${f##*/}" "${obj}"
            )
        done; unset f
    )

    set -- $(find -H ${libdir} -type f \( -name "*.dylib" -o -name "*.so" \))
    set +x
    i=0
    for f
    do
        ((i++))
        printf '\r%4d/%4d' ${i} ${#}
        case ${f} in
        *.dylib)
            change_id "${f}"
        ;;
        esac
        change_link "${f}"
    done; unset f
    echo
    set -x
)

make_distfile()
(
    ## WINELOADER
    install -m 0755 "${proj_root}"/wineloader.sh.in ${prefix}/bin/nihonshu

    ## INF
    install -d                                  ${prefix}/share/wine/inf
    cp "${proj_root}"/osx-wine-inf/osx-wine.inf ${prefix}/share/wine/inf/osx-wine.inf

    ## DOC
    install -m 0644 ${builddir}/wine/LICENSE ${prefix}/share/wine/LICENSE
    install -d                               ${prefix}/share/nihonshu
    install -m 0644 "${proj_root}"/LICENSE   ${prefix}/share/nihonshu/LICENSE
    echo "${proj_version}"                  >${prefix}/share/nihonshu/VERSION

    ## WINETRICKS
    install -m 0755 "${srcdir}"/winetricks/src/winetricks ${prefix}/bin/winetricks
    install -d                                            ${prefix}/share/winetricks
    install -m 0644 "${srcdir}"/winetricks/COPYING        ${prefix}/share/winetricks/COPYING
    install -m 0755 "${srcdir}"/cabextract/cabextract     ${prefix}/bin/cabextract

    ## FONT
    tar xf "${proj_root}"/contrib/VLGothic-20141206.tar.bz2 \
        -C ${prefix}/share/wine/fonts \
        --strip-components 1 \
        --include '*.ttf'

    ## ARCHIVE
    wine_version=$(${prefix}/bin/wine --version)
    wine_version=${wine_version/wine/wine64}
    distfile=${proj_root}/distfiles/${wine_version}_nihonshu-${proj_version}.tar.bz2
    touch "${distfile}" || mkdir -p "$(dirname "${distfile}")"
    tar cf - -C ${prefix} \
        --exclude './lib/cmake' \
        --exclude './lib/pkgconfig' \
        --exclude './libexec' \
        . \
    | bzip2 >"${distfile}"

    for f in "${proj_root}"/script.d/*.sh
    do
        test -f "${f}" || continue
        . "${f}"
    done
)

 init
 build_wine
 change_install_name
 make_distfile
