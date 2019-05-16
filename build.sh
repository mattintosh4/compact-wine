#!/usr/bin/env -i SHELL=/bin/sh COMMAND_MODE=unix2003 LANG=C LC_ALL=C /bin/ksh
 set -e
 set -u
 set -x

prjdir=$(cd "$(dirname "${0}")" && pwd)
srcdir="${prjdir}"/src
ncpu=$(($(/usr/sbin/sysctl -n hw.logicalcpu) + 1))

dstroot=/tmp/local
prefix=${dstroot}
libdir=${dstroot}/lib
bindir=${prefix}/libexec/bin
incdir=${prefix}/libexec/include
builddir=/tmp/_build

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
    MACOSX_DEPLOYMENT_TARGET=10.10
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

init(){
    test ! -d ${dstroot} \
    || rm -rf ${dstroot}
    mkdir -p  ${dstroot}

    test ! -d ${builddir} \
    || rm -rf ${builddir}
    mkdir -p  ${builddir}

    test -e "${srcdir}"/sdk.tar.bz2 || ./build-dep.sh
    tar xf "${srcdir}"/sdk.tar.bz2 -C ${dstroot}
}

save_time(){
    printf '%s\t%s\n' "$(date)" "${*}" >>${builddir}/build.log
}

build_wine()(
    name=wine-stable
    rsync -a --delete "${srcdir}"/src/${name} ${builddir}/${name}
    cd ${builddir}/${name}

    patch_wine

    args=(
        --prefix=${prefix}
        --with-cms
        --with-png
        --with-freetype
        --with-x
        --x-includes=/opt/X11/include
        --x-libraries=/opt/X11/lib
    )

    for f in \
        m64 \
        m32 \
    
    do
        test ! -d ${builddir}/${name}/${f} \
        || rm -rf ${builddir}/${name}/${f}
        mkdir -p  ${builddir}/${name}/${f}
        cd        ${builddir}/${name}/${f}

        case ${f} in
        m32)
            ../configure "${args[@]}" --with-win64=../m64
            make -j ${ncpu}
        ;;
        m64)
            ../configure "${args[@]}" --enable-win64
            make -j ${ncpu} dlldir=${libdir}
        ;;
        esac
    done; unset f

    for f in \
        m32 \
        m64 \
    
    do
        case ${f} in
        m32)
            make -j ${ncpu} install
        ;;
        m64)
            make -j ${ncpu} install dlldir=${libdir}
        ;;
        esac
    done

    ## universal
    lipo -create \
        -arch i386   ${builddir}/${name}/m32/libs/wine/libwine.1.0.dylib \
        -arch x86_64 ${builddir}/${name}/m64/libs/wine/libwine.1.0.dylib \
        -output                              ${libdir}/libwine.1.0.dylib

)

patch_wine()
(
    set -- "${prjdir}"/patch/wine___*.diff
    for f
    do
        test -e "${f}" || continue
        patch -Np1 <"${f}"
    done
)

change_install_name()
(
    is_external_lib?()
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
        *)
            return 0
        ;;
        esac
    )

    change_id()
    (
        obj=${1}
        save_IFS=${IFS} IFS=$'\n'
        set -- $(otool -D "${obj}")
        IFS=${save_IFS}
        shift || return 0 # truncate otool header
        is_external_lib? "${1}" || return 0
        install_name_tool -id @rpath/"${1##*/}" "${obj}"
        ;;
        esac
    )

    change_link()
    (
        obj=${1}
        set -- $(otool -L "${obj}" | grep -v "$(otool -D "${obj}")" | awk '{ print $1 }')
        for f
        do
            is_external_lib? "${f}" || continue
            install_name_tool -change "${f}" @rpath/"${f##*/}" "${obj}"
        done; unset f
    )

    set -- $(find -H ${libdir} -type f \( -name "*.dylib" -o -name "*.so" \))
    for f
    do
        case ${f} in
        *.dylib)
            change_id "${f}"
        ;;
        esac
        change_link "${f}"
    done; unset f
)

 init
 build_wine
 change_install_name
