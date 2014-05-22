#!/usr/bin/env - SHELL=/bin/sh TERM=xterm-256color COMMAND_MODE=unix2003 LANG=C LC_ALL=C /bin/ksh
set -e
set -o pipefail
set -u
set -x

CS_PATH=/usr/bin:/bin:/usr/sbin:/sbin
PATH=$CS_PATH
export PATH

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

define MACPORTSDIR      /opt/local
define XDIR             /opt/X11
define XINCDIR          ${XDIR}/include
define XLIBDIR          ${XDIR}/lib

PATH=\
${BINDIR}:\
${MACPORTSDIR}/libexec/ccache:\
${MACPORTSDIR}/libexec/git-core:\
$CS_PATH

AC_PATH=\
${MACPORTSDIR}/libexec/gnubin:\
${MACPORTSDIR}/bin:\
${MACPORTSDIR}/sbin:\
$CS_PATH

set -- `uname -r`
DARWIN_VERSION=$1

SFI=$IFS IFS=.
set -- `sw_vers -productVersion`
IFS=$SFI
MACOSX_DEPLOYMENT_TARGET=$1.$2
export MACOSX_DEPLOYMENT_TARGET

SFI=$IFS IFS=$'\n'
set -- `xcodebuild -version -sdk macosx$MACOSX_DEPLOYMENT_TARGET`
IFS=$SFI
for r
{
    set -- $r
    case $1 in
    Path:)
        SDKROOT=$2
        break
        ;;
    esac
}

TRIPLE=i686-apple-darwin$DARWIN_VERSION

set -a
define CC                   gcc-apple-4.2
define CXX                  g++-apple-4.2
define CFLAGS               -m32 -arch i386 -O3 -march=core2 -mtune=core2
define CPPFLAGS             -isysroot ${SDKROOT} -I${INCDIR}
define CXXFLAGS             ${CFLAGS}
define CXXCPPFLAGS          ${CPPFLAGS}
define LDFLAGS              -Wl,-headerpad_max_install_names -Wl,-syslibroot,${SDKROOT} -arch i386 -Z -L${LIBDIR} -L/usr/lib -F/System/Library/Frameworks

define CCACHE_PATH          ${MACPORTSDIR}/bin

define FONTFORGE            ${MACPORTSDIR}/bin/fontforge
define INSTALL_NAME_TOOL    ${MACPORTSDIR}/bin/install_name_tool
define MAKE                 ${MACPORTSDIR}/bin/gmake
define MSGFMT               ${MACPORTSDIR}/bin/msgfmt
define NASM                 ${MACPORTSDIR}/bin/nasm
define PKG_CONFIG           ${MACPORTSDIR}/bin/pkg-config
define PKG_CONFIG_LIBDIR    ${LIBDIR}/pkgconfig:/usr/lib/pkgconfig
set +a

for f in \
INSTALL_NAME_TOOL \
MAKE \
MSGFMT \
NASM \
PKG_CONFIG
{
    eval test -x '$'$f
}

#-------------------------------------------------------------------------------

autogen()
{
    PATH=${AC_PATH} NOCONFIGURE=1 ./autogen.sh ${@-}
}
autoreconf()
{
    PATH=${AC_PATH} NOCONFIGURE=1 command autoreconf -i ${@-}
}
configure()
{
    ./configure --prefix=${PREFIX} --build=${TRIPLE} --libdir=${LIBDIR} ${@-}
}
git_checkout()
{
    git checkout -f ${1-master}
}
make_install()
{
    $MAKE --jobs=3
    $MAKE install
}
clone_repos()
{
    rsync -a --delete ${SRCROOT}/${1}/ ${TMPDIR}/${1}
    cd ${TMPDIR}/${1}
}

#-------------------------------------------------------------------------------

build_freetype()
{
    typeset name
    name=freetype

    clone_repos ${name}
    git_checkout
    autogen
    configure --disable-static
    make_install
}

build_xz()
{
    typeset name
    name=xz

    clone_repos ${name}
    git_checkout v5.0
    autogen
    configure \
        --disable-dependency-tracking \
        --disable-nls \
        --disable-static
    make_install
}

build_jpeg()
{
    typeset name
    name=libjpeg-turbo

    clone_repos ${name}
    git_checkout
    sed -i '' '\|$(datadir)/doc|s||&/libjpeg-turbo|' Makefile.am
    autoreconf
    configure \
        --disable-dependency-tracking \
        --disable-static \
        --with-jpeg8
    make_install
}

build_tiff()
{
    typeset name
    name=libtiff

    clone_repos ${name}
    git_checkout branch-3-9
    configure \
        --disable-dependency-tracking \
        --disable-cxx \
        --disable-jbig \
        --disable-static \
        --with-apple-opengl-framework \
        --with-x \
        --x-inc=${XINCDIR} \
        --x-lib=${XLIBDIR}
    make_install
}

build_lcms()
{
    typeset name
    name=Little-CMS

    clone_repos ${name}
    git_checkout
    configure \
        --disable-dependency-tracking \
        --disable-static
    make_install
}

build_png()
{
    typeset name
    name=libpng

    clone_repos ${name}
    git_checkout libpng16
    autogen
    configure \
        --disable-dependency-tracking \
        --disable-static
    make_install
}

build_wine()
{
    typeset name
    name=wine

    typeset configure_args
    configure_args=(
        --prefix=${W_PREFIX}
        --build=${TRIPLE}
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
    )

    clone_repos ${name}
    git_checkout
    patch_wine
    git diff > $PROJECTROOT/wine___all.diff
    ./configure "${configure_args[@]}"
    make_install
}

#-------------------------------------------------------------------------------

patch_wine()
{
    set -- $PROJECTROOT/patch/wine___*.diff
    for f
    {
        test -f "$f" || continue
        patch -Np1 < $f
    }

    . $PROJECTROOT/patch_wine.sh
}

#-------------------------------------------------------------------------------

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

build_xz
build_png
build_jpeg
build_tiff
build_freetype
build_lcms
build_wine


change_id()
{
    src=$1
    set -- $(otool -XD $src)
    case $1 in
    $LIBDIR/*)
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
        $LIBDIR/*)
            (
                set -x
                $INSTALL_NAME_TOOL -change $1 @rpath/${1##*/} $src
            )
            ;;
        esac
    }
}

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

mkdir -p          $W_PREFIX/libexec
mv $W_BINDIR/wine $W_PREFIX/libexec
ln $PROJECTROOT/wineloader.sh.in $W_BINDIR/wine
mkdir -p                                  $W_DATADIR/wine/inf
ln $PROJECTROOT/osx-wine-inf/osx-wine.inf $W_DATADIR/wine/inf

$PROJECTROOT/patch_autogen.sh $PROJECTROOT
