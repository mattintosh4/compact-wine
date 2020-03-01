# REQUIRED VARIABLES
: ${proj_root:?}
: ${proj_version:?}
: ${wine_version:?}
: ${distfile:?}

mkdir -p "${proj_root}"/distfiles

appname=EasyWineRT
app=${proj_root}/distfiles/${appname}.app
test ! -e "${app}" || rm -r "${app}"

osacompile -o "${app}" "${proj_root}"/main.scpt

mkdir -p                "${app}"/Contents/Resources/wine
tar xf "${distfile}" -C "${app}"/Contents/Resources/wine

rm                      "${app}"/Contents/Resources/droplet.icns
install -m 0644         "${proj_root}"/contrib/Blackvariant-Button-Ui-System-Apps-BootCamp-2.icns \
                        "${app}"/Contents/Resources/easywine.icns

install -m 0755         "${proj_root}"/wineloader.sh.in.easywine \
                        "${app}"/Contents/Resources/wine/bin/nihonshu

mkdir -p                "${app}"/Contents/Resources/wine/lib/wine/nativedlls
#cp -a                   "${proj_root}"/rsrc/directx_Jun2010_redist/win32 \
#                        "${proj_root}"/rsrc/directx_Jun2010_redist/win64 \
#                        "${app}"/Contents/Resources/wine/lib/wine/nativedlls
cp -a                   "${proj_root}"/rsrc/nativedlls/win32 \
                        "${app}"/Contents/Resources/wine/lib/wine/nativedlls

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

add :CFBundleIdentifier         string com.github.mattintosh4.easywine-rt
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

patch -Np0 "${app}"/Contents/Resources/wine/share/wine/wine.inf <<!
--- EasyWineRT.app/Contents/Resources/wine/share/wine/wine.inf.orig 2019-11-12 11:51:54.000000000 +0900
+++ EasyWineRT.app/Contents/Resources/wine/share/wine/wine.inf  2019-11-13 23:55:23.000000000 +0900
@@ -543,11 +543,11 @@
 HKCU,Software\Wine\Debug,"RelayFromExclude",2,"winex11.drv;winemac.drv;user32;gdi32;advapi32;kernel32"

 [Replacements]
-HKCU,Software\Wine\Fonts\Replacements,"MS UI Gothic"   ,,"VL PGothic"
-HKCU,Software\Wine\Fonts\Replacements,"ＭＳ ゴシック"  ,,"VL Gothic"
-HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐゴシック",,"VL PGothic"
-HKCU,Software\Wine\Fonts\Replacements,"ＭＳ 明朝"      ,,"ヒラギノ明朝 ProN W3"
-HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐ明朝"    ,,"ヒラギノ明朝 ProN W3"
+HKCU,Software\Wine\Fonts\Replacements,"MS UI Gothic"   ,,"IPAMonaUIGothic"
+HKCU,Software\Wine\Fonts\Replacements,"ＭＳ ゴシック"  ,,"IPAMonaGothic"
+HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐゴシック",,"IPAMonaPGothic"
+HKCU,Software\Wine\Fonts\Replacements,"ＭＳ 明朝"      ,,"IPAMonaMincho"
+HKCU,Software\Wine\Fonts\Replacements,"ＭＳ Ｐ明朝"    ,,"IPAMonaPMincho"

 [DirectX]
 HKLM,Software\Microsoft\DirectX,"Version",,"4.09.00.0904"
@@ -613,6 +613,7 @@
 HKLM,%FontSubStr%,"Courier New TUR,162",,"Courier New,162"
 HKLM,%FontSubStr%,"Helv",,"MS Sans Serif"
 HKLM,%FontSubStr%,"Helvetica",,"Arial"
+HKLM,%FontSubStr%,"MS Shell Dlg",,"IPAMonaUIGothic"
 HKLM,%FontSubStr%,"MS Shell Dlg 2",,"Tahoma"
 HKLM,%FontSubStr%,"Times",,"Times New Roman"
 HKLM,%FontSubStr%,"Times New Roman Baltic,186",,"Times New Roman,186"
!

patch -Np0 "${app}"/Contents/Resources/wine/share/wine/inf/osx-wine.inf <<!
--- EasyWineRT.app/Contents/Resources/wine/share/wine/inf/osx-wine.inf.orig 2019-11-12 11:51:54.000000000 +0900
+++ EasyWineRT.app/Contents/Resources/wine/share/wine/inf/osx-wine.inf  2019-11-14 00:00:58.000000000 +0900
@@ -62,20 +62,16 @@

 ;;; FONT ;;;

-GothicMonoFile    = VL-Gothic-Regular.ttf
-GothicMonoName    = VL ゴシック
-GothicPropFile    = VL-PGothic-Regular.ttf
-GothicPropName    = VL Pゴシック
-GothicUIFile      = VL-PGothic-Regular.ttf
-GothicUIName      = VL Pゴシック
-;MinchoMonoFile    = VL-Gothic-Regular.ttf
-;MinchoMonoName    = VL ゴシック
-;MinchoPropFile    = VL-PGothic-Regular.ttf
-;MinchoPropName    = VL Pゴシック
-MinchoMonoFile    = ヒラギノ明朝 ProN W3.ttc
-MinchoMonoName    = ヒラギノ明朝 ProN W3
-MinchoPropFile    = ヒラギノ明朝 ProN W3.ttc
-MinchoPropName    = ヒラギノ明朝 ProN W3
+GothicMonoFile    = ipag-mona.ttf
+GothicMonoName    = IPAMonaGothic
+GothicPropFile    = ipagp-mona.ttf
+GothicPropName    = IPAMonaPGothic
+GothicUIFile      = ipagui-mona.ttf
+GothicUIName      = IPAMonaUIGothic
+MinchoMonoFile    = ipag-mona.ttf
+MinchoMonoName    = IPAMonaGothic
+MinchoPropFile    = ipagp-mona.ttf
+MinchoPropName    = IPAMonaPGothic



@@ -83,7 +79,7 @@

 HKCU,Control Panel\Mouse  ,"DoubleClickHeight"       ,          ,"8"
 HKCU,Control Panel\Mouse  ,"DoubleClickWidth"        ,          ,"8"
-HKCU,Control Panel\Desktop,"FontSmoothing"           ,          ,"2"
+HKCU,Control Panel\Desktop,"FontSmoothing"           ,          ,"0"
 HKCU,Control Panel\Desktop,"FontSmoothingGamma"      ,0x00010001,0x000004b0
 HKCU,Control Panel\Desktop,"FontSmoothingOrientation",0x00010001,0x00000001
 HKCU,Control Panel\Desktop,"FontSmoothingType"       ,0x00010001,0x00000002
!

(
    tempdir=$(mktemp -d)
    trap "rm -r ${tempdir}" EXIT
    cd ${tempdir}
    curl -O "http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu-ja/lucid-non-free/opfc-modulehp-ipamonafont-source_1.1.1+1.0.8-0ubuntu0ja1.tar.gz"
    tar xf opfc-modulehp-ipamonafont-source_1.1.1+1.0.8-0ubuntu0ja1.tar.gz --strip=2 "*/fonts"
#   rm                "${app}"/Contents/Resources/wine/share/wine/fonts/VL-Gothic-Regular.ttf
#   rm                "${app}"/Contents/Resources/wine/share/wine/fonts/VL-PGothic-Regular.ttf
    cp -a fonts/*.ttf "${app}"/Contents/Resources/wine/share/wine/fonts
    cp -a fonts/doc   "${app}"/Contents/Resources/wine/share/ipamonafont
)

mv "${app}"                         "${proj_root}"/distfiles/EasyWine
cp -a "${proj_root}"/SUPPORTERS.txt "${proj_root}"/distfiles/EasyWine

(
    cd "${proj_root}"/distfiles/EasyWine
    /opt/local/bin/7z a \
    "${proj_root}"/distfiles/${appname}_${proj_version}_${wine_version}.zip \
    "${appname}".app \
    SUPPORTERS.txt
)

unset app appname
