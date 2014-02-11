#!/usr/bin/env - SHELL=/bin/sh TERM=xterm-256color COMMAND_MODE=unix2003 LC_ALL=C LANG=C /bin/ksh
set -e
set -o pipefail
set -u
set -x

define(){ eval ${1}='"${*:2}"'; }

define CAT                  /bin/cat
define CHMOD                /bin/chmod
define CUT                  /usr/bin/cut
define FIND                 /usr/bin/find
define GETCONF              /usr/bin/getconf
define GREP                 /usr/bin/grep
define INSTALL_NAME_TOOL    /usr/bin/install_name_tool
define LN                   /bin/ln
define MKDIR                /bin/mkdir -p
define OTOOL                /usr/bin/otool
define PATCH                /usr/bin/patch
define RM                   /bin/rm
define RSYNC                /usr/bin/rsync -a
define SED                  /usr/bin/sed
define SW_VERS              /usr/bin/sw_vers
define UNAME                /usr/bin/uname
define XCODEBUILD           /usr/bin/xcodebuild

define PROJECTROOT      $(cd "$(dirname "$0")" && pwd)
define SRCROOT          ${PROJECTROOT}/src

define TMPDIR        /tmp/_build

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

CS_PATH=$(${GETCONF} PATH)

PATH=\
${BINDIR}:\
${MACPORTSDIR}/libexec/ccache:\
${MACPORTSDIR}/libexec/git-core:\
${MACPORTSDIR}/libexec/gnubin:\
${CS_PATH}
export PATH

AC_PATH=\
${MACPORTSDIR}/libexec/gnubin:\
${MACPORTSDIR}/bin:\
${MACPORTSDIR}/sbin:\
${CS_PATH}

DARWIN_VERSION=$(
    ${UNAME} -r
)
MACOSX_DEPLOYMENT_TARGET=$(
    ${SW_VERS} -productVersion \
    | ${CUT} -d. -f-2
)
export MACOSX_DEPLOYMENT_TARGET
SDKROOT=$(
    ${XCODEBUILD} -version -sdk macosx${MACOSX_DEPLOYMENT_TARGET} \
    | ${SED} -n "/^Path: /s///p"
)
TRIPLE=i686-apple-darwin${DARWIN_VERSION}

set -a
define CC                   gcc-apple-4.2
define CXX                  g++-apple-4.2
define CFLAGS               -m32 -arch i386 -O3 -mtune=generic
define CPPFLAGS             -isysroot ${SDKROOT} -I${INCDIR}
define CXXFLAGS             ${CFLAGS}
define CXXCPPFLAGS          ${CPPFLAGS}
define LDFLAGS              -Wl,-headerpad_max_install_names -Wl,-syslibroot,${SDKROOT} -arch i386 -Z -L${LIBDIR} -L/usr/lib -F/System/Library/Frameworks

define CCACHE_PATH          ${MACPORTSDIR}/bin

define FONTFORGE            ${MACPORTSDIR}/bin/fontforge
define MAKE                 ${MACPORTSDIR}/bin/gmake
define MSGFMT               ${MACPORTSDIR}/bin/msgfmt
define NASM                 ${MACPORTSDIR}/bin/nasm
define PKG_CONFIG           ${MACPORTSDIR}/bin/pkg-config
define PKG_CONFIG_LIBDIR    ${LIBDIR}/pkgconfig:/usr/lib/pkgconfig
set +a

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
    ${MAKE} --jobs=3
    ${MAKE} install
}
clone_repos()
{
    ${RSYNC} --delete ${SRCROOT}/${1}/ ${TMPDIR}/${1}
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
    ${SED} -i "" "s|\$(datadir)/doc|&/libjpeg-turbo|" Makefile.am
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
        --without-capi
        --without-gphoto
        --without-gsm
        --without-oss
        --without-sane
        --without-v4l
        --with-x
        --x-inc=${XINCDIR}
        --x-lib=${XLIBDIR}
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
    for f in $PROJECTROOT/patch/wine___*.diff
    {
        test -f "$f" || continue
        patch -Np1 < $f
    }

    . $PROJECTROOT/patch_wine.sh
}

#-------------------------------------------------------------------------------

${RM} -rf   ${INSTALL_PREFIX}
${RM} -rf   ${TMPDIR}

${MKDIR}    ${INSTALL_PREFIX}
${MKDIR}    ${TMPDIR}
${MKDIR}    ${W_BINDIR}
${MKDIR}    ${W_INCDIR}
${MKDIR}    ${W_LIBDIR}
${MKDIR}    ${BINDIR}
${MKDIR}    ${INCDIR}
${MKDIR}    ${LIBDIR}

build_xz
build_png
build_jpeg
build_tiff
build_freetype
build_lcms
build_wine

change_iname()
{
    src=$1

    case ${src} in
    *.dylib)
        set -- $(${OTOOL} -XD ${src})
        case ${1} in
        /*)
            ${INSTALL_NAME_TOOL} -id @rpath/${src##*/} ${src}
            ;;
        esac
        ;;
    esac

    set -- $(${OTOOL} -XL ${1} | ${GREP} -o '.*\.dylib')
    for f
    {
        case ${f} in
        ${LIBDIR}/*)
            ${INSTALL_NAME_TOOL} -change ${f} @rpath/${f##*/} ${src}
            ;;
        esac
    }
}

set -- $(
    ${FIND} ${W_LIBDIR} -type f \( -name "*.dylib" -o -name "*.so" \)
)

#for f
#{
#    change_iname ${f}
#}

LIBDIR=$LIBDIR \
/usr/bin/ruby - "$@" <<\!
ARGV.each {|f|
    %x[/usr/bin/otool -XD #{f}].each_line {|line|
        old = line.split[0]
        next if old.start_with?("@")
        new = File.join("@rpath", File.basename(old))
        cmd = ['/usr/bin/install_name_tool', '-id', new, f]
        if system(*cmd)
            p cmd
        else
            exit(1)
        end
    }

    %x[/usr/bin/otool -XL #{f}].each_line {|line|
        old = line.split[0]
        next unless old.start_with?(ENV["LIBDIR"])
        new = File.join("@rpath", File.basename(old))
        cmd = ['/usr/bin/install_name_tool', '-change', old, new, f]
        if system(*cmd)
            p cmd
        else
            exit(1)
        end
    }
}
!

${RM} -rf ${LIBDIR}/*.la
${RM} -rf ${LIBDIR}/pkgconfig
