app=${PROJECTROOT}/distfiles/EasyWine.app

rm -rf ${app}
mkdir -p ${PROJECTROOT}/distfiles
osacompile -o ${app} <<\!
on main(argv)
    set rcfile to quoted form of POSIX path of (path to resource "Scripts/Loader.sh")
    do shell script "/bin/sh -- " & rcfile & space & argv
end main

on run
    main("explorer")
end run

on open argv
    repeat with f in argv
        main("start /unix" & space & quoted form of POSIX path of f)
    end repeat
end open
!

cat >${app}/Contents/Resources/Scripts/Loader.sh <<\!
#!/bin/sh -e

BINDIR=$(cd "$(dirname "$0")"/../wine/bin && pwd)
PATH=${BINDIR}:/usr/bin:/bin

set -a
LANG=ja_JP.UTF-8

WINEPREFIX=${HOME}/Library/Caches/Wine/prefixes/default
WINEDEBUG=fixme-all

XDG_CACHE_HOME=${HOME}/Library/Caches/Wine
XDG_CONFIG_HOME=${HOME}/Library/Caches/Wine
XDG_DATA_HOME=${HOME}/Library/Caches/Wine
set +a

check_timestamp()
{
    read timestamp_ctime <"${WINEPREFIX}"/.update-timestamp || :
    case ${timestamp_ctime:+set} in
    set)
        ((`stat -f inf_ctime=%c -t %s "${BINDIR}"/../share/wine/wine.inf`))
        ((${timestamp_ctime} < ${inf_ctime})) || return 0
        ;;
    esac

    mkdir -p "${WINEPREFIX}"

    for f in "${BINDIR}"/../share/wine/inf/*.inf
    {
        test -f "${f}" || continue
        wine 'C:\windows\system32\rundll32.exe' \
             setupapi,InstallHinfSection DefaultInstall 128 \
             '\\?\'unix"${f}"
    }
}

check_timestamp
exec wine "${@}"
!

rm ${app}/Contents/Resources/droplet.icns
ditto ${INSTALL_PREFIX} ${app}/Contents/Resources/wine
/usr/libexec/PlistBuddy \
-c "add :CFBundleDocumentTypes:1:CFBundleTypeExtensions  array" \
-c "add :CFBundleDocumentTypes:1:CFBundleTypeExtensions: string exe" \
-c "add :CFBundleDocumentTypes:1:CFBundleTypeName        string Windows Executable File" \
-c "add :CFBundleDocumentTypes:1:CFBundleTypeMIMETypes   array" \
-c "add :CFBundleDocumentTypes:1:CFBundleTypeMIMETypes:  string application/x-msdownload" \
-c "add :CFBundleDocumentTypes:1:CFBundleTypeRole        string Shell" \
-c "add :CFBundleDocumentTypes:2:CFBundleTypeExtensions  array" \
-c "add :CFBundleDocumentTypes:2:CFBundleTypeExtensions: string lnk" \
-c "add :CFBundleDocumentTypes:2:CFBundleTypeName        string Windows File Shortcut" \
-c "add :CFBundleDocumentTypes:2:CFBundleTypeMIMETypes   array" \
-c "add :CFBundleDocumentTypes:2:CFBundleTypeMIMETypes:  string application/x-ms-shortcut" \
-c "add :CFBundleDocumentTypes:2:CFBundleTypeRole        string Shell" \
${app}/Contents/Info.plist

hdiutil create -ov -srcdir ${app} ${PROJECTROOT}/distfiles/EasyWine_`date +%F`.dmg
