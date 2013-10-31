#!/usr/bin/python
import os
import sys
import shutil
import subprocess

PROJECT_NAME = "wine"
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
SRCROOT      = os.path.join(PROJECT_ROOT, "src")

W_PREFIX     = os.path.join("/usr/local/dist", PROJECT_NAME)
W_BINDIR     = os.path.join(W_PREFIX,  "bin")
W_INCDIR     = os.path.join(W_PREFIX,  "include")
W_LIBDIR     = os.path.join(W_PREFIX,  "lib")
W_DATADIR    = os.path.join(W_PREFIX,  "share")
W_DOCDIR     = os.path.join(W_DATADIR, "doc")

PREFIX       = os.path.join(os.path.expandvars("$TMPDIR"), "local")
BLDROOT      = os.path.join(PREFIX,  "_build")
BINDIR       = os.path.join(PREFIX,  "bin")
INCDIR       = os.path.join(PREFIX,  "include")
LIBDIR       = os.path.join(PREFIX,  "lib")
DATADIR      = os.path.join(PREFIX,  "share")
DOCDIR       = os.path.join(DATADIR, "doc")

#-------------------------------------------------------------------------------

TRIPLET         = "i686-apple-darwin" + os.uname()[2]
SDKROOT         = "/Developer/SDKs/MacOSX10.6.sdk"
MACPORTS_PREFIX = "/opt/local"
X11_PREFIX      = "/opt/X11"
X11_INCDIR      = os.path.join(X11_PREFIX, "include")
X11_LIBDIR      = os.path.join(X11_PREFIX, "lib")

CC       = "clang-mp-3.3"
CXX      = "clang++-mp-3.3"
CFLAGS   = "-m32 -arch i386 -isysroot {SDKROOT}".format(**globals())
CPPFLAGS = "-I{INCDIR}".format(**globals())
LDFLAGS  = "-Wl,-arch,i386,-headerpad_max_install_names,-syslibroot,{SDKROOT} -L{LIBDIR}".format(**globals())

PATH = ":".join(
    """
    {BINDIR}
    {MACPORTS_PREFIX}/libexec/ccache
    {MACPORTS_PREFIX}/libexec/git-core
    {MACPORTS_PREFIX}/libexec/gnubin
    /usr/bin
    /bin
    /usr/sbin
    /sbin
    """.format(**globals()).split())

CCACHE_PATH = ":".join(
    """
    {MACPORTS_PREFIX}/bin
    """.format(**globals()).split())

PKG_CONFIG_LIBDIR = ":".join(
    """
    {LIBDIR}/pkgconfig
    {DATADIR}/pkgconfig
    /usr/lib/pkgconfig
    """.format(**globals()).split())

AC_PATH = ":".join(
    """
    {MACPORTS_PREFIX}/libexec/gnubin
    {MACPORTS_PREFIX}/bin
    {MACPORTS_PREFIX}/sbin
    /usr/bin
    /bin
    /usr/sbin
    /sbin
    """.format(**globals()).split())

FONTFORGE  = "{MACPORTS_PREFIX}/bin/fontforge".format(**globals())
MAKE       = "{MACPORTS_PREFIX}/bin/gmake".format(**globals())
MSGFMT     = "{MACPORTS_PREFIX}/bin/msgfmt".format(**globals())
NASM       = "{MACPORTS_PREFIX}/bin/nasm".format(**globals())
PKG_CONFIG = "{MACPORTS_PREFIX}/bin/pkg-config".format(**globals())

#-------------------------------------------------------------------------------

def set_env():
    os.environ["CC"]                = CC
    os.environ["CXX"]               = CXX
    os.environ["CFLAGS"]            = CFLAGS
    os.environ["CXXFLAGS"]          = CFLAGS
    os.environ["CPPFLAGS"]          = CPPFLAGS
    os.environ["CXXCPPFLAGS"]       = CPPFLAGS
    os.environ["LDFLAGS"]           = LDFLAGS

    os.environ["PATH"]              = PATH
    os.environ["CCACHE_PATH"]       = CCACHE_PATH
    os.environ["MAKE"]              = MAKE
    os.environ["PKG_CONFIG"]        = PKG_CONFIG
    os.environ["PKG_CONFIG_LIBDIR"] = PKG_CONFIG_LIBDIR

#-------------------------------------------------------------------------------

def check_system(cmd):
    cmd = "set -e\n" + cmd
    retcode = os.system(cmd)
    if retcode: sys.exit(1)

def autogen(*args):
    cmd = ["./autogen.sh"]
    cmd.extend(args)
    env = {"PATH": AC_PATH, "NOCONFIGURE": "1"}
    subprocess.check_call(cmd, env=env)

def autoreconf(*args):
    cmd = ["autoreconf", "-i"]
    cmd.extend(args)
    env = {"PATH": AC_PATH, "NOCONFIGURE": "1"}
    subprocess.check_call(cmd, env=env)

def configure(*args, **kwargs):
    _configure_vars = kwargs
    _configure_vars.setdefault("prefix",  PREFIX)
    _configure_vars.setdefault("triplet", TRIPLET)
    cmd = \
"""
./configure
--build={triplet}
--prefix={prefix}
""".format(**_configure_vars).split()
    cmd.extend(args)
    print >> sys.stderr, "*** %s ***" % " ".join(cmd)
    subprocess.check_call(cmd)

def git_checkout(branch="master"):
    cmd = ["git", "checkout", "-f", branch]
    subprocess.check_call(cmd)

def make(*args):
    cmd = ["make", "--jobs=2"]
    cmd.extend(args)
    subprocess.check_call(cmd)

def make_install():
    make("install")

def reposcopy(name):
    src = os.path.join(SRCROOT, name)
    dst = os.path.join(BLDROOT, name)
    shutil.copytree(src, dst)
    os.chdir(dst)

def install_doc(name):
    dstroot = os.path.join(DOCDIR, name)
    if not os.path.exists(dstroot): os.makedirs(dstroot)
    docs = [
        "ANNOUNCE",
        "AUTHORS",
        "CHANGES",
        "COPYING",
        "ChangeLog",
        "ChangeLog.txt",
        "LICENSE",
        "README",
    ]
    for f in docs:
        src = os.path.join(BLDROOT, name, f)
        if os.path.exists(src):
            shutil.copy2(src, dstroot)

#-------------------------------------------------------------------------------

def build_freetype(name="freetype"):
    reposcopy(name)
    git_checkout()
    autogen()
    configure()
    make()
    make_install()
    install_doc(name)


def build_jpeg(name="libjpeg-turbo"):
    reposcopy(name)
    git_checkout()
    subprocess.check_call(["sed", "-i", ".orig", "s|$(datadir)/doc|&/libjpeg-turbo|", "Makefile.am"])
    autoreconf()
    configure(
        "--disable-dependency-tracking",
        "--with-jpeg8",
        "NASM={NASM}".format(**globals()),
    )
    make()
    make_install()


def build_lcms(name="Little-CMS"):
    reposcopy(name)
    git_checkout()
    configure(
        "--disable-dependency-tracking",
    )
    make()
    make_install()
    install_doc(name)


def build_png(name="libpng"):
    reposcopy(name)
    git_checkout("libpng16")
    autogen()
    configure(
        "--disable-dependency-tracking",
    )
    make()
    make_install()
    install_doc(name)


def build_tiff(name="libtiff"):
    reposcopy(name)
    git_checkout("branch-3-9")
    configure(
        "--disable-dependency-tracking",
        "--disable-jbig",
        "--without-x",
    )
    make()
    make_install()


def build_wine(name="wine", prefix=W_PREFIX):

    def _add_rpath(exe=os.path.join(prefix, "bin", "wine")):
        subprocess.check_call(["install_name_tool", "-add_rpath", X11_LIBDIR, exe])
        subprocess.check_call(["install_name_tool", "-add_rpath", "/usr/lib", exe])

    reposcopy(name)
    git_checkout()
#    git_checkout("wine-1.7.4")
    check_system(
"""
patch -Np1 < {PROJECT_ROOT}/osx-wine-patch/wine_autohidemenu.patch
patch -Np1 < {PROJECT_ROOT}/osx-wine-patch/wine_change_locale.patch
patch -Np1 < {PROJECT_ROOT}/osx-wine-patch/wine_exclude_desktop.patch
patch -Np1 < {PROJECT_ROOT}/osx-wine-patch/wine_exclude_fonts.patch
patch -Np1 < {PROJECT_ROOT}/osx-wine-patch/wine_translate_menu.patch
""".format(**globals()))

    configure(
*"""
--without-capi
--without-gphoto
--without-gsm
--without-oss
--without-sane
--without-v4l
--with-x
--x-inc={X11_INCDIR}
--x-lib={X11_LIBDIR}
FONTFORGE={FONTFORGE}
MSGFMT={MSGFMT}
""".format(**globals()).split(), **locals())
    make()
    make_install()

    _add_rpath()


def build_xz(name="xz"):
    reposcopy(name)
    git_checkout()
    autogen()
    configure(
        "--disable-dependency-tracking",
        "--disable-nls",
    )
    make()
    make_install()

#-------------------------------------------------------------------------------

def create_dirs():
    for f in [
        W_PREFIX,
        PREFIX,
    ]:
        os.path.exists(f) and shutil.rmtree(f)

    for f in [
        W_PREFIX,
        W_BINDIR,
        W_INCDIR,
        W_LIBDIR,
        W_DATADIR,
        W_DOCDIR,

        PREFIX,
        BINDIR,
        INCDIR,
#        LIBDIR,
        DATADIR,
#        DOCDIR,

        BLDROOT,
    ]:
        os.makedirs(f)

    os.symlink(W_LIBDIR, LIBDIR)
    os.symlink(W_DOCDIR, DOCDIR)


def create_exec_symlink():
    for f in os.listdir(LIBEXECDIR)[:]:
        src = os.path.join("../libexec", f)
        dst = os.path.join(BINDIR, f)
        os.symlink(src, dst)


def rpath():
    cmd = [os.path.join(PROJECT_ROOT, "rpath.sh"), PREFIX]
    subprocess.check_call(cmd)

#-------------------------------------------------------------------------------

if __name__ == "__main__":

    create_dirs()
    set_env()

    build_xz()
    build_png()
    build_freetype()
    build_jpeg()
    build_tiff()
    build_lcms()
    build_wine()

    rpath()

    check_system("{W_BINDIR}/wine --version".format(**globals()))
