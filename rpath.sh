#!/bin/sh
set -e
set -u

define(){ eval $1=\"\${*:2}\"; }

define PREFIX   $1
define LIBDIR   $PREFIX/lib

define FIND                 /usr/bin/find
define GREP                 /usr/bin/grep
define INSTALL_NAME_TOOL    /usr/bin/install_name_tool
define OTOOL                /usr/bin/otool
define RM                   /bin/rm

#-------------------------------------------------------------------------------

install_name_tool()
{
    /bin/sh -xc "$INSTALL_NAME_TOOL \"\$@\"" -- "$@"
}

rm()
{
    /bin/sh -xc "$RM \"\$@\"" -- "$@"
}

#-------------------------------------------------------------------------------

change_install_name()
{
    if [ "$($OTOOL -XD $1 | $GREP -v @rpath)" ]
    then
        install_name_tool -id @rpath/${1##*/} $1
    fi

    $OTOOL -XL $1 | grep $LIBDIR | cut -d" " -f1 |
    while read f
    do
        install_name_tool -change $f @rpath/${f##*/} $1
    done
}

#-------------------------------------------------------------------------------

$FIND $LIBDIR/* |
while read
do
    case $REPLY in
    $LIBDIR/wine/*.a|\
    $LIBDIR/wine/*.la)
        continue
        ;;
    *.dylib|\
    *.so)
        [ ! -L $REPLY ] || continue
        change_install_name $REPLY
        ;;
    *.a|\
    *.la)
        rm $REPLY
        ;;
    */pkgconfig)
        rm -r $REPLY
        ;;
    esac
done
