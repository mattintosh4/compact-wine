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
    CFLAGS+=" -arch i386"
    CFLAGS+=" -arch x86_64"
    CFLAGS+=" -O2"
#   CFLAGS+=" -std=gnu89"
    CFLAGS+=" -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
    CXXFLAGS=
    CXXFLAGS+=" -arch i386"
    CXXFLAGS+=" -arch x86_64"
    CXXFLAGS+=" -O2"
#   CXXFLAGS+=" -stdlib=libc++"
    CPPFLAGS=
    CPPFLAGS+=" -isysroot ${SDKROOT}"
    CPPFLAGS+=" -I${incdir}"
    LDFLAGS=
    LDFLAGS+=" -Wl,-headerpad_max_install_names"
    LDFLAGS+=" -Wl,-syslibroot,${SDKROOT}"
    LDFLAGS+=" -Wl,-macosx_version_min,${MACOSX_DEPLOYMENT_TARGET}"
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

    mkdir -p  ${bindir}
    mkdir -p  ${incdir}
    mkdir -p  ${libdir}

    test ! -d ${builddir} \
    || rm -rf ${builddir}
    mkdir -p  ${builddir}
    
    ln -sf /opt/local/bin/ccache ${bindir}/ccache
    ln -sf ccache                ${bindir}/clang
    ln -sf ccache                ${bindir}/clang++
    ln -sf ccache                ${bindir}/gcc
    ln -sf ccache                ${bindir}/g++
    ln -sf ccache                ${bindir}/cc
    ln -sf ccache                ${bindir}/c++
    
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
            xz \

        set -- $(env HOME= /opt/local/bin/port contents "${@}" | grep '/opt/local/bin/.*')
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

save_time(){
    printf '%s\t%s\n' "$(date)" "${*}" >>${builddir}/build.log
}

create_archive(){
    tar cf - -C $(dirname ${libdir}) . | bzip2 >"${srcdir}"/sdk.tar.bz2
}

build_ncurses()(
    name=ncurses
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}
    cd ${builddir}/${name}
    git checkout master
    args=(
        --prefix=${prefix}
        --enable-widec
        --disable-lib-suffixes
        --enable-overwrite
        --with-shared
        --with-cxx-shared
        --without-debug
        --without-ada
        --with-manpage-format=normal
        --enable-pc-files
        --disable-mixed-case
    )
    ./configure "${args[@]}"
    make -j ${ncpu}
    make install
)

build_zlib()(
    name=zlib
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
    git checkout master
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
    )
    CFLAGS="${CFLAGS} ${CPPFLAGS}" ./configure "${args[@]}"
    make -j ${ncpu}
    save_time // ${name} make
    make -j ${ncpu} install
    save_time // ${name} make install
)

build_libpng()(
    name=libpng
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}
    cd ${builddir}/${name}
    git checkout master
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-dependency-tracking
        --disable-static
    )
    ./configure "${args[@]}"
    make -j ${ncpu}
    save_time // ${name} make
    make -j ${ncpu} install
    save_time // ${name} make install
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
    ./configure "${args[@]}"
    make -j ${ncpu}
    save_time // ${name} make
    make -j ${ncpu} install
    save_time // ${name} make install
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
    make -j ${ncpu}
    make -j ${ncpu} install
)


build_libjpeg()(
    name=libjpeg-turbo
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}
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
    make -j ${ncpu}
    save_time // ${name} make
    make -j ${ncpu} install
    save_time // ${name} make install
)

build_libtiff()(
    name=libtiff
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}
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
    make -j ${ncpu}
    save_time // ${name} make
    make -j ${ncpu} install
    save_time // ${name} make install
)

build_lcms()(
    name=Little-CMS
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}
    cd ${builddir}/${name}
    git checkout master
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-dependency-tracking
        --disable-static
    )
    ./configure "${args[@]}"
    make -j ${ncpu}
    save_time // ${name} make
    make -j ${ncpu} install
    save_time // ${name} make install
)

build_openssl()
(
    name=openssl
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}/
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --openssldir=${prefix}/etc/openssl
        shared
    )

    ## 32-bit
    mkdir -p ${builddir}/${name}32
    cd ${builddir}/${name}32
    CFLAGS=${CFLAGS// -arch x86_64/} /usr/bin/perl ../${name}/Configure "${args[@]}" darwin-i386-cc
    make
    save_time // ${name} 32 make
    make test
    save_time // ${name} 32 make test
    make install
    save_time // ${name} 32 make install

    ## 64-bit
    mkdir -p ${builddir}/${name}64
    cd ${builddir}/${name}64
    CFLAGS=${CFLAGS// -arch i386/}   /usr/bin/perl ../${name}/Configure "${args[@]}" darwin64-x86_64-cc
    make
    save_time // ${name} 64 make
    make test
    save_time // ${name} 64 make test
    make install
    save_time // ${name} 64 make install

    for f in \
        crypto \
        ssl \

    do
        lipo -create \
            -arch i386   ${builddir}/openssl32/lib${f}.3.dylib \
            -arch x86_64 ${builddir}/openssl64/lib${f}.3.dylib \
            -output                  ${libdir}/lib${f}.3.dylib
    done
)

build_nettle()(
#   name=nettle-3.4.1
#   test ! -d ${builddir}/${name} \
#   || rm -rf ${builddir}/${name}
#   mkdir  -p ${builddir}/${name}
#   cd        ${builddir}/${name}
    name=nettle
    rsync -a --delete "${srcdir}"/repos/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
    autoreconf -vfi
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-documentation
        --disable-static
        --disable-openssl
        --enable-shared
        --enable-fat
    )

    for f in \
        m32 \
        m64 \

    do
        mkdir -p ${builddir}/${name}/${f}
        cd       ${builddir}/${name}/${f}

        case ${f} in
        m32) CFLAGS=${CFLAGS// -arch x86_64/} CXXFLAGS=${CXXFLAGS// -arch x86_64/} ../configure "${args[@]}" --build=i686-apple-darwin$(uname -r)  ;;
        m64) CFLAGS=${CFLAGS// -arch i386/}   CXXFLAGS=${CXXFLAGS// -arch i386/}   ../configure "${args[@]}" --build=x86_64-apple-darwin$(uname -r);;
        esac

        make -j ${ncpu}
        make -j ${ncpu} install
    done; unset f

    ## universal
    lipo -create \
        -arch i386    ${builddir}/${name}/m32/libhogweed.dylib \
        -arch x86_64  ${builddir}/${name}/m64/libhogweed.dylib \
        -output                     ${libdir}/libhogweed.5.0.dylib
    lipo -create \
        -arch i386    ${builddir}/${name}/m32/libnettle.dylib \
        -arch x86_64  ${builddir}/${name}/m64/libnettle.dylib \
        -output                     ${libdir}/libnettle.7.0.dylib
)

build_gmp()(
    name=gmp-6.1.2
    test ! -d ${builddir}/${name} \
    || rm -rf ${builddir}/${name}
    tar xf "${srcdir}"/repos/${name}.tar.xz -C ${builddir}

    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-static
        --enable-cxx
        --enable-fat
    )

    ## 32bit / 64-bit
    for f in \
        m32 \
        m64 \

    do
        mkdir -p ${builddir}/${name}/${f}
        cd       ${builddir}/${name}/${f}

        case ${f} in
        m32) ABI=32 CFLAGS=${CFLAGS// -arch x86_64} CXXFLAGS=${CXXFLAGS// -arch x86_64} ../configure "${args[@]}" --host=i686-apple-darwin$(uname -r)  ;;
        m64) ABI=64 CFLAGS=${CFLAGS// -arch i386}   CXXFLAGS=${CXXFLAGS// -arch i386}   ../configure "${args[@]}" --host=x86_64-apple-darwin$(uname -r);;
        esac

        make -j ${ncpu}
        make -j ${ncpu} check
 
        case ${f} in
        m64) sed "
                s|@__CFLAGS_32__@|${CFLAGS// -arch x86_64}|
                s|@__CFLAGS_64__@|${CFLAGS// -arch i386}|
             " <<\! | patch gmp.h
--- gmp.h.orig  2019-05-14 23:19:08.000000000 +0900
+++ gmp.h       2019-05-14 23:37:30.000000000 +0900
@@ -40,7 +40,11 @@
 #if ! defined (__GMP_WITHIN_CONFIGURE)
 #define __GMP_HAVE_HOST_CPU_FAMILY_power   0
 #define __GMP_HAVE_HOST_CPU_FAMILY_powerpc 0
+#ifndef __LP64__
+#define GMP_LIMB_BITS                      32
+#else
 #define GMP_LIMB_BITS                      64
+#endif
 #define GMP_NAIL_BITS                      0
 #endif
 #define GMP_NUMB_BITS     (GMP_LIMB_BITS - GMP_NAIL_BITS)
@@ -2317,7 +2321,11 @@
 
 /* Define CC and CFLAGS which were used to build this version of GMP */
 #define __GMP_CC "/opt/local/bin/ccache clang"
+#ifndef __LP64__
+#define __GMP_CFLAGS "@__CFLAGS_32__@"
+#else
 #define __GMP_CFLAGS "@__CFLAGS_64__@"
+#endif
 
 /* Major version number is the value of __GNU_MP__ too, above. */
 #define __GNU_MP_VERSION            6
!
        ;;
        esac

        make -j ${ncpu} install
    done; unset f

    ## univresal
    for f in \
        gmp.10 \
        gmpxx.4 \

    do
        lipo -create \
            -arch i386   ${builddir}/${name}/m32/.libs/lib${f}.dylib \
            -arch x86_64 ${builddir}/${name}/m64/.libs/lib${f}.dylib \
            -output ${libdir}/lib${f}.dylib
    done; unset f
)

build_libtasn1()(
    name=libtasn1-4.13
    test ! -d ${builddir}/${name} \
    || rm -rf ${builddir}/${name}
    tar xf "${srcdir}"/repos/${name}.tar.gz -C ${builddir}
    cd ${builddir}/${name}
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-static
        --disable-silent-rules
    )
    ./configure "${args[@]}"
    make -j ${ncpu}
    make -j ${ncpu} install
)

build_libunistring()(
    name=libunistring-0.9.10
    test ! -d ${builddir}/${name} \
    || rm -rf ${builddir}/${name}
    tar xf "${srcdir}"/repos/${name}.tar.gz -C ${builddir}
    cd ${builddir}/${name}
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-static
    )
    ./configure "${args[@]}"
    make -j ${ncpu}
    make -j ${ncpu} install
)

build_libffi()(
    name=libffi
    rsync -a --delete "${srcdir}"/repos/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-static
        --disable-docs
    )
    ./autogen.sh

    for f in \
        m32 \
        m64 \

    do
        mkdir -p ${builddir}/${name}/${f}
        cd       ${builddir}/${name}/${f}
        case ${f} in
        m32) CFLAGS=${CFLAGS// -arch x86_64/} CXXFLAGS=${CXXFLAGS// -arch x86_64/} ../configure "${args[@]}";;
        m64) CFLAGS=${CFLAGS// -arch i386/}   CXXFLAGS=${CXXFLAGS// -arch i386/}   ../configure "${args[@]}";;
        esac
        make -j ${ncpu}
        make -j ${ncpu} install
    done; unset f

    ## universal
    lipo -create \
        -arch i386   ${builddir}/${name}/m32/.libs/libffi.7.dylib \
        -arch x86_64 ${builddir}/${name}/m64/.libs/libffi.7.dylib \
        -output                          ${libdir}/libffi.7.dylib
)

build_p11_kit()(
    name=p11-kit-0.23.15
    test ! -d ${builddir}/${name} \
    || rm -rf ${builddir}/${name}
    tar xf "${srcdir}"/repos/${name}.tar.gz -C ${builddir}
    cd ${builddir}/${name}
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-doc
        --disable-silent-rules
        --with-trust-paths=${prefix}/share/curl/curl-ca-bundle.crt:${prefix}/etc/openssl
    )
    ./configure "${args[@]}"
    make -j ${ncpu}
    make -j ${ncpu} install
)

build_gnutls()(
    name=gnutls-3.6.7
    test ! -d ${builddir}/${name} \
    || rm -rf ${builddir}/${name}
    tar xf "${srcdir}"/repos/${name}.1.tar.xz -C ${builddir}
    cd ${builddir}/${name}
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-silent-rules
        --disable-doc
        --disable-gtk-doc
        --disable-gtk-doc-html
        --disable-gtk-doc-pdf
        --disable-guile
        --disable-libdane
        --disable-ssl2-support
        --disable-ssl3-support
        --disable-static
        --enable-openssl-compatibility
        --enable-shared
        --with-default-trust-store-pkcs11=pkcs11
        --with-p11-kit
        --with-system-priority-file=${prefix}/etc/gnutls/default-properties
    )
    for f in \
        m32 \
        m64 \

    do
        mkdir -p ${builddir}/${name}/${f}
        cd       ${builddir}/${name}/${f}
        case ${f} in
        m32) CFLAGS=${CFLAGS// -arch x86_64/} CFLAGS=${CFLAGS// -std=gnu89/} CXXFLAGS=${CXXFLAGS// -arch x86_64/} ../configure "${args[@]}" --build=i686-apple-darwin$(uname -r)  ;;
        m64) CFLAGS=${CFLAGS// -arch i386/}   CFLAGS=${CFLAGS// -std=gnu89/} CXXFLAGS=${CXXFLAGS// -arch i386/}   ../configure "${args[@]}" --build=x86_64-apple-darwin$(uname -r);;
        esac
        make -j ${ncpu}
        make -j ${ncpu} install
    done; unset f

    ## universal
    for f in \
        extra/.libs/libgnutls-openssl.27.dylib \
          lib/.libs/libgnutls.30.dylib \
          lib/.libs/libgnutlsxx.28.dylib \

    do
        lipo -create \
            -arch i386   ${builddir}/${name}/m32/${f} \
            -arch x86_64 ${builddir}/${name}/m64/${f} \
            -output ${libdir}/${f##*/}
    done; unset f
)

build_libusb()(
    name=libusb
    rsync -a --delete "${srcdir}"/repos/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
    args=(
        --prefix=${prefix}
        --libdir=${libdir}
        --disable-static
        --disable-silent-rules
    )
    NOCONFIGURE=1 ./autogen.sh
    ./configure "${args[@]}"
    make -j ${ncpu}
    make -j ${ncpu} install
)

build_openal(){
    name=openal-soft
    rsync -a --delete "${srcdir}"/${name}/ ${builddir}/${name}/
    cd ${builddir}/${name}
    git checkout master
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
    make -j ${ncpu}
    save_time // ${name} make
    make -j ${ncpu} install
    save_time // ${name} make install
}

 init
 build_openal
 build_libpng
 build_freetype
 build_harfbuzz
 build_freetype
#build_libjpeg
#build_libtiff
 build_lcms
 create_archive
