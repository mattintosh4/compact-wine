# REQUIRED VARIABLES
: ${proj_root:?}
: ${proj_version:?}
: ${wine_version:?}
: ${distfile:?}

mkdir -p "${proj_root}"/distfiles

app=${proj_root}/distfiles/EasyWine.app
test ! -e "${app}" || rm -r "${app}"

osacompile -o "${app}" <<\!
on main(argv)
  set beginning of argv to quoted form of POSIX path of (path to me) & "Contents/Resources/wine/bin/nihonshu"
  set beginning of argv to "WINEPREFIX=$HOME/Library/Caches/Wine/prefixes/default"
  set beginning of argv to "WINEDEBUG=-all"
  set end       of argv to "&>/dev/null &"
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

mkdir -p                "${app}"/Contents/Resources/wine
tar xf "${distfile}" -C "${app}"/Contents/Resources/wine
rm "${app}"/Contents/Resources/droplet.icns
install -m 0644 "${proj_root}"/contrib/Blackvariant-Button-Ui-System-Apps-BootCamp-2.icns \
                "${app}"/Contents/Resources/easywine.icns

mkdir -p "${app}"/Contents/Resources/wine/lib/wine/nativedlls
tempdir=`mktemp -d`
(
  cd ${tempdir}
  set -- 38 39 40 41 42 43
  for f
  do
    /opt/local/bin/7z e -y "${proj_root}"/rsrc/directx_Jun2010_redist.exe -i"!*d3dx9_${f}_x86.cab"
    /opt/local/bin/7z e -y *_d3dx9_${f}_x86.cab d3dx9_${f}.dll
  done
  
  /opt/local/bin/7z e -y "${proj_root}"/rsrc/directx_Jun2010_redist.exe -i"!*X3DAudio_x86.cab"
  for f in *_X3DAudio_x86.cab
  do
    /opt/local/bin/7z e -y ${f} -i"!*.dll"
  done
  for f in *.dll
  do
    f=`echo ${f} | tr [:upper:] [:lower:]`
    cp -a ${f} "${app}"/Contents/Resources/wine/lib/wine/nativedlls/${f}
  done
)
rm -rf ${tempdir}
unset tempdir
install -m 0755 "${proj_root}"/wineloader.sh.in.easywine \
                "${app}"/Contents/Resources/wine/bin/nihonshu

CFBundleGetInfoString="\
nihonshu-${proj_version}, \
${wine_version} \
© `date +%Y` mattintosh4, https://github.com/mattintosh4"
while read
do
  test "${REPLY}" || continue
  /usr/libexec/PlistBuddy -c "${REPLY}" "${app}"/Contents/Info.plist
done <<!
set :CFBundleDevelopmentRegion  ja_JP
set :CFBundleIconFile           easywine

add :CFBundleIdentifier         string com.github.mattintosh4.easywine
add :CFBundleGetInfoString      string ${CFBundleGetInfoString}
add :CFBundleShortVersionString string ${proj_version}
add :CFBundleVersion            string ${proj_version}

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

rm -rf      "${proj_root}"/distfiles/EasyWine
mkdir -p    "${proj_root}"/distfiles/EasyWine
mv "${app}" "${proj_root}"/distfiles/EasyWine
hdiutil create \
  -ov \
  -format UDBZ \
  -fs HFS+J \
  -srcdir "${proj_root}"/distfiles/EasyWine \
  -volname EasyWine-${proj_version} \
  "${proj_root}"/distfiles/EasyWine-${proj_version}_${wine_version}.dmg

unset app
