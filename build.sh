#!/usr/bin/env - PATH=/usr/bin:/bin:/usr/sbin:/sbin SHELL=/bin/sh TERM=xterm-256color COMMAND_MODE=unix2003 LANG=C LC_ALL=C /bin/ksh
set -e
set -o pipefail
set -u
set -x

PROJECT_VERSION=`date +%Y%m%d`

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

PATH=\
/tmp/local/bin:\
$__TOOLPREFIX__CCACHE__:\
$__TOOLPREFIX__GIT__:\
$__TOOLPREFIX__GETTEXT__:\
$__TOOLPREFIX__AUTOTOOLS__:\
$__TOOLPREFIX__XZ__:\
`xcode-select -print-path`/usr/bin:\
$__CS_PATH__


set -a
CCACHE_PATH=\
/tmp/_build/bin:\
`xcode-select -print-path`/usr/bin:\
/usr/bin:\
$__MACPORTSPREFIX__/bin

# CC=gcc-apple-4.2
#CXX=g++-apple-4.2
# CC=gcc
#CXX=g++
 CC="clang"
CXX="clang++"
MACOSX_DEPLOYMENT_TARGET=10.6
SDKROOT=`xcodebuild -version -sdk macosx10.9 | awk '/^Path/ { print $2 }'`
  CFLAGS="-m32 -arch i386 -O3 -mtune=generic -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -isysroot ${SDKROOT} -I${INCDIR}"
CXXFLAGS=${CFLAGS}
case ${CC} in
clang*)
      CFLAGS="${CFLAGS} -std=gnu89 -g"
    CXXFLAGS="${CFLAGS}"
;;
esac
LDFLAGS="\
${CFLAGS} \
-Wl,-arch,i386 \
-Wl,-macosx_version_min,${MACOSX_DEPLOYMENT_TARGET} \
-Wl,-headerpad_max_install_names \
-Wl,-syslibroot,${SDKROOT} \
-Z -L${LIBDIR} -L/usr/lib -F/System/Library/Frameworks"

INSTALL_NAME_TOOL=$__MACPORTSPREFIX__/bin/install_name_tool

PKG_CONFIG=$__MACPORTSPREFIX__/bin/pkg-config
PKG_CONFIG_PATH=
PKG_CONFIG_LIBDIR=\
${LIBDIR}/pkgconfig:\
/usr/lib/pkgconfig

NASM=${__MACPORTSPREFIX__}/bin/nasm

ac_tool_prefix=/opt/local/bin
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
    git_checkout VER-2-6-5
    ./autogen.sh
    args=(
        --prefix=$PREFIX
        --build=$__TRIPLE__
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
        --build=$__TRIPLE__
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
    git_checkout 1.5.0
    autoreconf -fvi
    args=(
        --prefix=$PREFIX
        --libdir=$LIBDIR
        --build=${__TRIPLE__}
        --host=${__TRIPLE__}
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
        --build=$__TRIPLE__
        --libdir=$LIBDIR
        --disable-dependency-tracking
        --disable-cxx
        --disable-jbig
        --disable-static
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
        --build=$__TRIPLE__
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
    git_checkout remotes/origin/libpng15
    ./autogen.sh
    args=(
        --prefix=$PREFIX
        --build=$__TRIPLE__
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
    latest_version=`git tag --sort=v:refname --contain 5b1e70ce97454c8b22ec3d55d2543968eef4cb2d | tail -n 1`
    git_checkout ${latest_version}

    ## This variable is needed patching.
    args=(
        --prefix=${W_PREFIX}
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

    # Generate original behavior module
    git checkout dlls/winemac.drv/cocoa_window.m
    make dlls/winemac.drv
    mv ${LIBDIR}/wine/winemac.drv.so \
       ${LIBDIR}/wine/winemac_autohide.drv.so
    install -m 0755 \
      dlls/winemac.drv/winemac.drv.so \
      ${LIBDIR}/wine/winemac_nohide.drv.so
    ln -s \
      winemac_autohide.drv.so \
      ${LIBDIR}/wine/winemac.drv.so
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

    mkdir -p                     ${PREFIX}/bin
    ln -fs /opt/local/bin/ccache ${PREFIX}/bin
    ln -fs ccache                ${PREFIX}/bin/clang
    ln -fs ccache                ${PREFIX}/bin/clang++
    ln -fs ccache                ${PREFIX}/bin/gcc
    ln -fs ccache                ${PREFIX}/bin/g++
    ln -fs ccache                ${PREFIX}/bin/cc
    ln -fs ccache                ${PREFIX}/bin/c++
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

    rm -f  $LIBDIR/*.a
    rm -f  $LIBDIR/*.la
    rm -rf $LIBDIR/pkgconfig

#    mkdir -p          $W_PREFIX/libexec
#    mv $W_BINDIR/wine $W_PREFIX/libexec
#    ln $PROJECTROOT/wineloader.sh.in $W_BINDIR/wine

    # WINELOADER
    install -m 0755 ${PROJECTROOT}/wineloader.sh.in ${W_BINDIR}/nihonshu

    # INF
    install -d                                  ${W_DATADIR}/wine/inf
    ln ${PROJECTROOT}/osx-wine-inf/osx-wine.inf ${W_DATADIR}/wine/inf

    # DOC
    install -m 0644 ${TMPDIR}/wine/LICENSE ${W_DATADIR}/wine
    install -d                             ${W_DATADIR}/nihonshu
    install -m 0644 ${PROJECTROOT}/LICENSE ${W_DATADIR}/nihonshu/LICENSE
    echo ${PROJECT_VERSION}               >${W_DATADIR}/nihonshu/VERSION

    # WINETRICKS
    install -m 0755 ${SRCROOT}/winetricks/src/winetricks  ${W_BINDIR}/winetricks
    install -d                                           ${W_DATADIR}/winetricks
    install -m 0644 ${SRCROOT}/winetricks/COPYING        ${W_DATADIR}/winetricks/COPYING

    WINE_VERSION=`${W_BINDIR}/wine --version`
    DISTFILE=${PROJECTROOT}/distfiles/${WINE_VERSION}_nihonshu-${PROJECT_VERSION}.tar.bz2

    tar cjf ${DISTFILE} -C ${INSTALL_PREFIX%/*} wine

    sed "/@PROJECTROOT@/s||${PROJECTROOT}|g
         /@WINE_VERSION@/s||${WINE_VERSION}|g
    " ${PROJECTROOT}/patch_autogen.sh.in | sh -s

    for f in ${PROJECTROOT}/script.d/*.sh
    {
        test -f ${f} || continue
        . ${f}
    }
}

mkdir -p ${TMPDIR}

env | sort

select n in \
wine-all \
wine \
xz \
libpng \
freetype \
libjpeg \
libtiff \
lcms \
distfile
do
case ${n:-REPLY} in
wine-all)
    init
#    build_zlib
#    build_xz
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
distfile)
    build_wine
    make_distfile
    ;;
'')
    continue
    ;;
esac
exit
done
