# REQUIRED VARIABLES
: ${PROJECTROOT:?}
: ${PROJECT_VERSION:?}
: ${WINE_VERSION:?}
: ${DISTFILE:?}

mkdir -p ${PROJECTROOT}/distfiles

app=${PROJECTROOT}/distfiles/EasyWine.app
test ! -e ${app} || rm -r ${app}

osacompile -o ${app} <<\!
on main(argv)
  set beginning of argv to quoted form of POSIX path of (path to resource "wine/bin/nihonshu")
  set beginning of argv to "WINEPREFIX=$HOME/Library/Caches/Wine/prefixes/default"
  set beginning of argv to "WINEDEBUG=-all"
--set end       of argv to "&>/dev/null &"
  set temp to text item delimiters of AppleScript
  set text item delimiters of AppleScript to space
  set argv to argv as string
  set text item delimiters of AppleScript to temp
  do shell script argv
end main

on run
  main({"explorer"})
end run

on open argv
  repeat with f in argv
    main({"start", "/unix", quoted form of POSIX path of f})
  end repeat
end open
!

tar xf ${DISTFILE} -C ${app}/Contents/Resources
rm ${app}/Contents/Resources/droplet.icns
install -m 0644 ${PROJECTROOT}/contrib/Blackvariant-Button-Ui-System-Apps-BootCamp-2.icns \
                ${app}/Contents/Resources/easywine.icns

CFBundleGetInfoString="\
nihonshu-${PROJECT_VERSION}, \
${WINE_VERSION} \
© `date +%Y` mattintosh4, https://github.com/mattintosh4"
while read
do
  test "${REPLY}" || continue
  /usr/libexec/PlistBuddy -c "${REPLY}" ${app}/Contents/Info.plist
done <<!
set :CFBundleDevelopmentRegion  ja_JP
set :CFBundleIconFile           easywine

add :CFBundleIdentifier         string com.github.mattintosh4.easywine
add :CFBundleGetInfoString      string ${CFBundleGetInfoString}
add :CFBundleShortVersionString string ${PROJECT_VERSION}
add :CFBundleVersion            string ${PROJECT_VERSION}

add :CFBundleDocumentTypes:1:CFBundleTypeExtensions  array
add :CFBundleDocumentTypes:1:CFBundleTypeExtensions: string exe
add :CFBundleDocumentTypes:1:CFBundleTypeIconFile    string easywine
add :CFBundleDocumentTypes:1:CFBundleTypeName        string Windows Executable File
add :CFBundleDocumentTypes:1:CFBundleTypeMIMETypes   array
add :CFBundleDocumentTypes:1:CFBundleTypeMIMETypes:  string application/x-msdownload
add :CFBundleDocumentTypes:1:CFBundleTypeRole        string Shell

add :CFBundleDocumentTypes:2:CFBundleTypeExtensions  array
add :CFBundleDocumentTypes:2:CFBundleTypeExtensions: string lnk
add :CFBundleDocumentTypes:2:CFBundleTypeIconFile    string easywine
add :CFBundleDocumentTypes:2:CFBundleTypeName        string Windows File Shortcut
add :CFBundleDocumentTypes:2:CFBundleTypeMIMETypes   array
add :CFBundleDocumentTypes:2:CFBundleTypeMIMETypes:  string application/x-ms-shortcut
add :CFBundleDocumentTypes:2:CFBundleTypeRole        string Shell

add :CFBundleDocumentTypes:3:CFBundleTypeExtensions  array
add :CFBundleDocumentTypes:3:CFBundleTypeExtensions: string msi
add :CFBundleDocumentTypes:3:CFBundleTypeIconFile    string easywine
add :CFBundleDocumentTypes:3:CFBundleTypeName        string Microsoft Windows Installer
add :CFBundleDocumentTypes:3:CFBundleTypeMIMETypes   array
add :CFBundleDocumentTypes:3:CFBundleTypeMIMETypes:  string application/x-msi
add :CFBundleDocumentTypes:3:CFBundleTypeRole        string Shell
!

hdiutil create \
  -ov \
  -format UDBZ \
  -srcdir ${app} \
  -volname EasyWine-${PROJECT_VERSION} \
  ${PROJECTROOT}/distfiles/EasyWine-${PROJECT_VERSION}_${WINE_VERSION}.dmg

unset app
