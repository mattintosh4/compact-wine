#!/usr/bin/env -i SHELL=/bin/sh COMMAND_MODE=unix2003 LANG=C LC_ALL=C /bin/ksh
 set -e
 set -u
 set -x

proj_root=$(cd "$(dirname "${0}")" && pwd)
srcdir="${proj_root}"/src
ncpu=$(($(/usr/sbin/sysctl -n hw.logicalcpu) + 1))

dstroot=/tmp/local
prefix=${dstroot}/libexec
libdir=${dstroot}/lib
bindir=${prefix}/bin
incdir=${prefix}/include
builddir=/tmp/_build

. ${proj_root}/envs.sh

set -a
    CFLAGS+=" -arch i386"
    CFLAGS+=" -arch x86_64"
    CFLAGS+=" -O2"

    CXXFLAGS+=" -arch i386"
    CXXFLAGS+=" -arch x86_64"
    CXXFLAGS+=" -O2"

    LDFLAGS+=" -arch i386"
    LDFLAGS+=" -arch x86_64"
set +a

init(){
    rmkdir ${builddir}
    rmkdir ${dstroot}
    rmkdir ${bindir}
    rmkdir ${incdir}
    rmkdir ${libdir}

    ln -sf ${CCACHE} ${bindir}/ccache
    ln -sf ccache    ${bindir}/cc
    ln -sf ccache    ${bindir}/c++
    ln -sf ccache    ${bindir}/gcc
    ln -sf ccache    ${bindir}/g++
    ln -sf ccache    ${bindir}/clang
    ln -sf ccache    ${bindir}/clang++

    (
        set -- \
            autoconf \
            automake \
            bison \
            cmake \
            flex \
            fontforge \
            gettext \
            libtool \
            nasm \
            pkgconfig \
            ragel \
            xz \

        set -- $(port contents "${@}" | grep '/opt/local/bin/.*')
        for f
        do
            test -x "${f}" || exit 1
            ln -sf ${f} ${bindir}
        done
    )
}

change_link(){
    save_IFS=${IFS} IFS=$'\n'
    set -- $(find -H ${libdir} -type f -name "*.dylib")
    IFS=${save_IFS}
    for obj
    do
        set -- $(otool -L "${obj}" | awk -v regexp="${f}" '$0 !~ regexp { print $1 }')
        for link
        do
            case ${link} in
            /System/Library/*|\
            /usr/lib/*|\
            @rpath/*)
                # do nothing
            ;;
            *)
                install_name_tool -change "${link}" @rpath/"${link##*/}" "${obj}"
            ;;
            esac
        done
    done
}

create_archive(){
    mkdir -p ${libdir}64
    cd       ${libdir}64
        for f in ../lib/*.dylib
        do
            test -f "${f}" || continue
            ln -s "${f}"
        done
    cd -

    tar cf - -C $(dirname ${libdir}) . \
    | bzip2 >"${srcdir}"/sdk.tar.bz2
}

build_libpng()(
    name=libpng
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}
    cd ${builddir}/${name}
    git checkout master
    args=(
        --prefix=${prefix}
        --disable-dependency-tracking
        --disable-static
    )
    ./configure "${args[@]}" --libdir=${libdir}
    save_time ${name} make
    make
    make install
    save_time ${name} make install
)

build_freetype()(
    name=freetype
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
    git checkout master
    ./autogen.sh
    /usr/bin/sed -E -i '' 's|.*(AUX_MODULES.*valid)|\1|' modules.cfg
    /usr/bin/sed -E -i '' '
        s|.* (#.*SUBPIXEL_RENDERING) .*|\1|
        s|.* (#.*FT_CONFIG_OPTION_USE_PNG) .*|\1|
    ' include/freetype/config/ftoption.h
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-dependency-tracking
        --disable-static
        --enable-freetype-config
        --with-png
    )
    ./configure "${args[@]}" --libdir=${libdir}
    save_time ${name} make
    make
    make install
    save_time ${name} make install
)

build_harfbuzz()(
    name=harfbuzz
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
    git checkout master
    NOCONFIGURE=1 ./autogen.sh
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-dependency-tracking
        --disable-silent-rules
    )
    ./configure "${args[@]}"
    save_time ${name} make
    make 
    make install
    save_time ${name} make install
)


build_libjpeg()(
    name=libjpeg-turbo
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
    git checkout master
    cmake -DCMAKE_INSTALL_PREFIX=${prefix} \
        -DWITH_JPEG8=1 \
        -DWITH_SIMD=0 \
        -DENABLE_STATIC=0 \
        -DCMAKE_INSTALL_NAME_DIR=${libdir} \
        -DCMAKE_INSTALL_LIBDIR=${libdir} \
    .
    cmake -L
    save_time ${name} make
    make
    make install
    save_time ${name} make install
)

build_libtiff()(
    name=libtiff
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
    git checkout master
    ./autogen.sh
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-dependency-tracking
        --disable-cxx
        --disable-jbig
        --disable-static
        --without-x
    )
    ./configure "${args[@]}"
    save_time ${name} make
    make
    make install
    save_time ${name} make install
)

build_lcms()(
    name=Little-CMS
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
    git checkout master
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-dependency-tracking
        --disable-static
    )
    ./configure "${args[@]}"
    save_time ${name} make
    make
    make install
    save_time ${name} make install
)

build_openal(){
    name=openal-soft
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
#   git checkout master
    git checkout -b temp openal-soft-1.19.1
    mkdir _build
    cd    _build
    cmake -DCMAKE_INSTALL_PREFIX=${prefix} \
          -DCMAKE_INSTALL_NAME_DIR=${libdir} \
          -DCMAKE_INSTALL_LIBDIR=${libdir} \
          -DCMAKE_SYSROOT=${SDKROOT} \
          -DCMAKE_FIND_ROOT_PATH=${SDKROOT} \
          -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
          -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
          -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
          -DALSOFT_EXAMPLES=OFF \
    ..
    cmake -L ..
    save_time ${name} make
    make
    make install
    save_time ${name} make install
}

build_mpg123(){(
    name=mpg123-1.25.13
#   rsync -a --delete "${srcdir}"/${name}-1.25.13/ ${builddir}/${name}
    tar xjf "${srcdir}"/${name}.tar.bz2 -C ${builddir}
    cd ${builddir}/${name}
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-dependency-tracking
        --disable-static
        --with-audio=coreaudio
    )

    mkdir m32
    cd m32
        CFLAGS=${CFLAGS/ -arch x86_64} \
        LDFLAGS=${LDFLAGS/ -arch x86_64} \
        ../configure "${args[@]}" --with-cpu=i586
        save_time ${name} make
        make -w all
    cd -

    mkdir m64
    cd m64
        CFLAGS=${CFLAGS/ -arch i386} \
        LDFLAGS=${LDFLAGS/ -arch i386} \
        ../configure "${args[@]}" --with-cpu=x86-64
        save_time ${name} make
        make -w all
    cd -

    # LIBRARIES
    mkdir -p ${libdir}
    lipo -create \
        -arch i386   m32/src/libmpg123/.libs/libmpg123.0.dylib \
        -arch x86_64 m64/src/libmpg123/.libs/libmpg123.0.dylib \
        -output                    ${libdir}/libmpg123.0.dylib
    ln -sf libmpg123.0.dylib   ${libdir}/libmpg123.dylib
    # HEADERS
    mkdir -p                                  ${incdir}
    install -m 644     src/libmpg123/fmt123.h ${incdir}
    install -m 644 m64/src/libmpg123/mpg123.h ${incdir}
    # PKG-CONFIG
    mkdir -p                        ${libdir}/pkgconfig
    install -m 644 m64/libmpg123.pc ${libdir}/pkgconfig
)}

 init
 build_mpg123
 build_openal
 build_libpng
 build_freetype
 build_harfbuzz
 build_freetype
 build_libjpeg
 build_libtiff
 build_lcms
 create_archive
