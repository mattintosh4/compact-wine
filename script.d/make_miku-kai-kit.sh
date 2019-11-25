#!/bin/sh -eux

### 必須変数 ###
: ${proj_root:?}
: ${proj_version:?}
: ${wine_version:?}
: ${distfile:?}

tempdir=`mktemp -d`/
trap "rm -r ${tempdir}" EXIT

osacompile -o ${tempdir}MikuInstaller-Kai-Kit.app <<\!
set CommandScript to quoted form of POSIX path of (path to resource "update.command")

tell app "Finder"
  activate
  display alert "MikuInstaller-Kai-Kit 使用許諾" ¬
    message "本アプリケーションは MikuInstaller-20080803.dmg にのみ使用できます。

本アプリケーションを使用した際の損害等について当方は一切の責任を負いません。" ¬
    buttons {"キャンセル", "承諾"} ¬
    cancel button "キャンセル"
  set DiskImage to quoted form of POSIX path of (choose file with prompt "MikuInstaller-20080803.dmg を選択してください")
end

tell app "Terminal"
  activate
  do script CommandScript & space & DiskImage
end
!

resourcesdir=${tempdir}MikuInstaller-Kai-Kit.app/Contents/Resources/

### WINE ソースの展開 ###
tar xf ${distfile} -C ${resourcesdir}

### 不要ファイルの削除 ###
rm -f ${resourcesdir}wine/bin/nihonshu

### リソースの展開 ###
install -m 0755 ${proj_root}/miku-kai-kit/update.command.in \
                ${resourcesdir}update.command
cp -R ${proj_root}/miku-kai-kit/patch \
      ${resourcesdir}

### バージョン文字列の置換 ###
sed -i '' -e "
  s|@PROJECT_VERSION@|${proj_version}|g
  s|@WINE_VERSION@|${wine_version}|g
" \
${resourcesdir}update.command \
${resourcesdir}patch/*.diff

### ディスクイメージ作成 ###
hdiutil create \
  -ov \
  -format UDBZ \
  -fs HFS+J \
  -srcdir ${tempdir}MikuInstaller-Kai-Kit.app \
  -volname MikuInstaller-Kai-Kit \
  "${proj_root}"/distfiles/MikuInstaller-Kai-Kit_${wine_version}.dmg

### 終了処理 ###
unset tempdir
unset resourcesdir
