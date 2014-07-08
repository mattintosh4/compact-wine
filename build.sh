#!/usr/bin/env - PATH=/usr/bin:/bin:/usr/sbin:/sbin SHELL=/bin/sh TERM=xterm-256color COMMAND_MODE=unix2003 LANG=C LC_ALL=C /bin/ksh
set -e
set -o pipefail
set -u
set -x

MACOSX_DEPLOYMENT_TARGET=`sw_vers -productVersion \
    | cut -d. -f-2`
SDKROOT=`xcodebuild -version -sdk macosx${MACOSX_DEPLOYMENT_TARGET} \
    | sed -n '/^Path: /s///p'`

__CS_PATH__=/usr/bin:/bin:/usr/sbin:/sbin
__TRIPLE__=i686-apple-darwin`uname -r`
__MACPORTSPREFIX__=/opt/local
__TOOLPREFIX__AUTOTOOLS__=$__MACPORTSPREFIX__/libexec/autotools
__TOOLPREFIX__CCACHE__=$__MACPORTSPREFIX__/libexec/ccache
__TOOLPREFIX__GETTEXT__=$__MACPORTSPREFIX__/libexec/gettext
__TOOLPREFIX__GIT__=$__MACPORTSPREFIX__/libexec/git-core
__TOOLPREFIX__XZ__=$__MACPORTSPREFIX__/libexec/xz

define(){ eval ${1}='"${*:2}"'; }

define PROJECTROOT      $(cd "$(dirname "$0")" && pwd)
define SRCROOT          ${PROJECTROOT}/src

define TMPDIR           /tmp/_build

define INSTALL_PREFIX   /usr/local/wine
define W_PREFIX         ${INSTALL_PREFIX}
define W_BINDIR         ${W_PREFIX}/bin
define W_INCDIR         ${W_PREFIX}/include
define W_LIBDIR         ${W_PREFIX}/lib
define W_DATADIR        ${W_PREFIX}/share
define PREFIX           /tmp/local
define BINDIR           ${PREFIX}/bin
define INCDIR           ${PREFIX}/include
define LIBDIR           ${W_PREFIX}/lib
define DATADIR          ${PREFIX}/share

define XDIR             /opt/X11
define XINCDIR          ${XDIR}/include
define XLIBDIR          ${XDIR}/lib

PATH=
PATH+=:$__TOOLPREFIX__CCACHE__
PATH+=:$__TOOLPREFIX__GIT__
PATH+=:$__TOOLPREFIX__GETTEXT__
PATH+=:$__TOOLPREFIX__AUTOTOOLS__
PATH+=:$__TOOLPREFIX__XZ__
PATH+=:$__CS_PATH__
PATH=${PATH#?}

set -a
CCACHE_PATH=
CCACHE_PATH+=:/usr/bin
CCACHE_PATH+=:$__MACPORTSPREFIX__/bin
CCACHE_PATH=${CCACHE_PATH#?}

CC=gcc-apple-4.2
CXX=g++-apple-4.2
CFLAGS="-m32 -arch i386 -O3 -march=core2 -mtune=core2"
CXXFLAGS=${CFLAGS}
CPPFLAGS=
CPPFLAGS+=" -isysroot $SDKROOT"
CPPFLAGS+=" -I$INCDIR"
LDFLAGS=" -arch i386"
LDFLAGS+=" -Wl,-headerpad_max_install_names"
LDFLAGS+=" -Wl,-syslibroot,$SDKROOT"
LDFLAGS+=" -Z -L$LIBDIR -L/usr/lib -F/System/Library/Frameworks"

INSTALL_NAME_TOOL=$__MACPORTSPREFIX__/bin/install_name_tool

PKG_CONFIG=$__MACPORTSPREFIX__/bin/pkg-config
PKG_CONFIG_PATH=
PKG_CONFIG_LIBDIR=
PKG_CONFIG_LIBDIR+=:${LIBDIR}/pkgconfig
PKG_CONFIG_LIBDIR+=:/usr/lib/pkgconfig
PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR#?}
set +a

#-------------------------------------------------------------------------------

git_checkout()
{
    : ${1:?}

    git checkout -f -B temp $1
}
clone_repos()
{
    : ${1:?}

    rsync -a --delete ${SRCROOT}/./${1}/ ${TMPDIR}/${1}
    cd ${TMPDIR}/${1}
}

#-------------------------------------------------------------------------------

build_zlib()
{
    clone_repos zlib
    git_checkout remotes/origin/master
    args=(
        --prefix=${PREFIX}
        --libdir=${LIBDIR}
        --archs="-arch i386"
    )
    ./configure "${args[@]}"
    make -j3
    make install
}

build_freetype()
{
    clone_repos freetype
    git_checkout remotes/origin/master
    ./autogen.sh
    args=(
        --prefix=$PREFIX
        --libdir=$LIBDIR
        --disable-static
    )
    ./configure ${args[@]}
    make -j3
    make install
}
build_xz()
{
    clone_repos xz
    git_checkout remotes/origin/v5.0
    ./autogen.sh
    args=(
        --prefix=$PREFIX
        --libdir=$LIBDIR
        --disable-dependency-tracking
        --disable-nls
        --disable-static
        --disable-xz
        --disable-xzdec
        --disable-lzmadec
        --disable-lzmainfo
        --disable-lzma-links
        --disable-scripts
    )
    ./configure ${args[@]}
    make -j3
    make install
}

build_libjpeg()
{
    clone_repos libjpeg-turbo
    git_checkout remotes/1.3.x
    autoreconf -vi
    args=(
        --prefix=$PREFIX
        --libdir=$LIBDIR
        --build=$__TRIPLE__
        --disable-dependency-tracking
        --disable-static
        --with-jpeg8
    )
    ./configure ${args[@]}
    make -j3 V=1
    make install
}

build_libtiff()
{
    clone_repos libtiff
    git_checkout master
    args=(
        --prefix=$PREFIX
        --libdir=$LIBDIR
        --disable-dependency-tracking
        --disable-cxx
        --disable-jbig
        --disable-static
        --with-apple-opengl-framework
        --with-x
        --x-inc=${XINCDIR}
        --x-lib=${XLIBDIR}
    )
    ./configure ${args[@]}
    make -j3
    make install
}

build_lcms()
{
    clone_repos Little-CMS
    git_checkout remotes/origin/master
    args=(
        --prefix=$PREFIX
        --libdir=$LIBDIR
        --disable-dependency-tracking
        --disable-static
    )
    ./configure ${args[@]}
    make -j3
    make install
}

build_libpng()
{
    clone_repos libpng
    git_checkout remotes/origin/libpng16
    ./autogen.sh
    args=(
        --prefix=$PREFIX
        --libdir=$LIBDIR
        --disable-dependency-tracking
        --disable-static
    )
    ./configure ${args[@]}
    make -j3
    make install
}

build_wine()
{
    clone_repos wine
#    git_checkout remotes/origin/master
    git_checkout wine-1.7.21
    ## This variable is needed patching.
    args=(
        --prefix=${W_PREFIX}
        --build=$__TRIPLE__
        --disable-win16
        --with-cms
        --with-coreaudio
        --with-cups
        --with-curses
        --with-freetype
        --with-jpeg
        --with-openal --with-opencl --with-opengl
        --with-png
        --with-pthread
        --with-tiff
        --with-xml
        --with-xslt
        --with-zlib
        --with-x
        --x-inc=${XINCDIR}
        --x-lib=${XLIBDIR}
        --without-capi
        --without-gphoto
        --without-gsm
        --without-oss
        --without-sane
        --without-v4l
#        "XML2_CFLAGS=-I/usr/include/libxml2"
#        "XML2_LIBS=-L/usr/lib -lxml2"
#        "XSLT_CFLAGS=-I/usr/include -I/usr/include/libxml2"
#        "XSLT_LIBS=-L/usr/lib -lxslt -lxml2"
    )
    patch_wine
    ./configure "${args[@]}"
    make -j3
    make install
}

#-------------------------------------------------------------------------------

patch_wine()
{
    set -- $PROJECTROOT/patch/wine___*.diff
    for f
    {
        test -f "$f" || continue
        patch -Np1 < "$f"
    }

    . $PROJECTROOT/patch_wine.sh
    git diff > $PROJECTROOT/wine___all.diff
}

#-------------------------------------------------------------------------------

init()
{
    rm -rf   ${INSTALL_PREFIX}
    rm -rf   ${TMPDIR}

    mkdir -p ${INSTALL_PREFIX}
    mkdir -p ${TMPDIR}
    mkdir -p ${W_BINDIR}
    mkdir -p ${W_INCDIR}
    mkdir -p ${W_LIBDIR}
    mkdir -p ${BINDIR}
    mkdir -p ${INCDIR}
    mkdir -p ${LIBDIR}
}

make_distfile()
{
    change_id()
    {
        src=$1
        set -- $(otool -XD $src)
        case $1 in
        $LIBDIR/*|/opt/X11/lib*)
            (
                set -x
                $INSTALL_NAME_TOOL -id @rpath/${1##*/} $src
            )
            ;;
        esac
    }
    change_link()
    {
        src=$1
        IFS=$'\n'
        set -- $(otool -XL $src)
        IFS=$' \t\n'
        for r
        {
            set -- $r
            case $1 in
            $LIBDIR/*|/opt/X11/lib/*)
                (
                    set -x
                    $INSTALL_NAME_TOOL -change $1 @rpath/${1##*/} $src
                )
                ;;
            esac
        }
    }

    _xlibcopy()
    {
        set -- `otool -XL $1 | grep -o '/opt/X11/lib/.*\.dylib'`
        for f
        {
            ! test -f ${LIBDIR}/${f##*/} || continue
            ditto --arch i386 ${f} ${LIBDIR}
            _xlibcopy ${f}
        }
    }
    _xlibcopy $LIBDIR/wine/glu32.dll.so

    set +x
    IFS=$'\n'
    set -- `find -L $LIBDIR -type f \( -name "*.dylib" -o -name "*.so" \)`
    IFS=$' \t\n'
    for f
    {
        case $f in
        *.dylib)
            change_id $f
            ;;
        esac
        change_link $f
    }
    set -x

    rm -rf $LIBDIR/*.la
    rm -rf $LIBDIR/pkgconfig

#    mkdir -p          $W_PREFIX/libexec
#    mv $W_BINDIR/wine $W_PREFIX/libexec
#    ln $PROJECTROOT/wineloader.sh.in $W_BINDIR/wine

    install -d                                  ${W_DATADIR}/wine/inf
    ln ${PROJECTROOT}/osx-wine-inf/osx-wine.inf ${W_DATADIR}/wine/inf

    install -m 0644 ${SRCROOT}/wine/LICENSE ${W_DATADIR}/wine
    install -d                              ${W_DATADIR}/nihonshu
    install -m 0644 ${PROJECTROOT}/LICENSE  ${W_DATADIR}/nihonshu

    tar cjf ${INSTALL_PREFIX%/*}/wine-$(cut -d' ' -f3 ${TMPDIR}/wine/VERSION)_nihonshu.tar.bz2 \
        -C ${INSTALL_PREFIX%/*} wine

    WINE_VERSION=`cat VERSION`
    sed "/@PROJECTROOT@/s||${PROJECTROOT}|g
         /@WINE_VERSION@/s||${WINE_VERSION}|g
    " ${PROJECTROOT}/patch_autogen.sh.in | sh -s
}


mkdir -p ${TMPDIR}

select n in \
wine-all \
wine \
xz \
libpng \
freetype \
libjpeg \
libtiff \
lcms
do
case ${n:-REPLY} in
wine-all)
    init
    build_zlib
    build_xz
    build_libpng
    build_freetype
    build_libjpeg
    build_libtiff
    build_lcms
    build_wine
    make_distfile
    ;;
wine)
    build_wine
    ;;
xz)
    build_xz
    ;;
libpng)
    build_libpng
    ;;
libjpeg)
    build_libjpeg
    ;;
libtiff)
    build_libtiff
    ;;
lcms)
    build_lcms
    ;;
'')
    continue
    ;;
esac
exit
done
