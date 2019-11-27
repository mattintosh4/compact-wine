    CFLAGS_32="-arch i386"
    CFLAGS_64="-arch x86_64"
set -a
    LANG=C
    LC_ALL=C

    PATH=/dev/null
    PATH+=:${bindir}
    PATH+=:/opt/local/libexec/gnubin
#   PATH+=:/opt/local/libexec/coreutils
#   PATH+=:$(/usr/bin/xcode-select -print-path)/usr/bin
    PATH+=:$(/usr/bin/getconf PATH)

    MACOSX_DEPLOYMENT_TARGET=10.7
    SDKROOT=$(xcrun --show-sdk-path)

    CCACHE=/usr/local/bin/ccache
    CCACHE_PATH=/usr/bin:/opt/local/bin
#       CC="ccache clang"
#      CPP="ccache clang -E"
#      CXX="ccache clang++"
#   CXXCPP="ccache clang++ -E"

    CFLAGS=
    CFLAGS+=" -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"

    CXXFLAGS=
#   CXXFLAGS+=" -stdlib=libc++"

    CPPFLAGS=
    CPPFLAGS+=" -isysroot ${SDKROOT}"
    CPPFLAGS+=" -I${incdir}"
#   CPPFLAGS+=" -I/opt/X11/include"

    LDFLAGS=
    LDFLAGS+=" -Wl,-syslibroot,${SDKROOT}"
    LDFLAGS+=" -Wl,-macosx_version_min,${MACOSX_DEPLOYMENT_TARGET}"
    LDFLAGS+=" -Wl,-headerpad_max_install_names"
#   LDFLAGS+=" -Wl,-rpath,/opt/X11/lib"
#   LDFLAGS+=" -Z"
    LDFLAGS+=" -L${libdir}"
#   LDFLAGS+=" -L/opt/X11/lib"
#   LDFLAGS+=" -F/System/Library/Frameworks"

    PKG_CONFIG_LIBDIR=
    PKG_CONFIG_LIBDIR+=:${libdir}/pkgconfig
#   PKG_CONFIG_LIBDIR+=:/opt/X11/lib/pkgconfig
    PKG_CONFIG_LIBDIR+=:/usr/lib/pkgconfig
    PKG_CONFIG_PATH=
set +a

make(){
    n=$(/usr/sbin/sysctl -n hw.logicalcpu)
    j=$((n > 1 ? n - 1 : n))
    command make -j ${j} "${@}"
    unset n j
}
port(){
    HOME= /opt/local/bin/port "${@}"
}
rmkdir(){(
    for f
    do
        test ! -d "${f}" \
        || rm -rf "${f}"
        mkdir -p  "${f}"
    done
)}
save_time(){
    printf '%s\t%s\n' "$(date)" "${*}" >>${builddir}/build.log
}
