# REQUIRED VARIABLES
: ${proj_root:?}
: ${proj_version:?}
: ${wine_version:?}
: ${distfile:?}

### CREATE WORKING DIRECTORY ###
tempdir=`mktemp -d`
mkdir -p ${tempdir}/wine
tar xf "${distfile}" -C ${tempdir}/wine
mv ${tempdir}/{wine,wswine.bundle}
wswine_bundle=${tempdir}/wswine.bundle

### UPDATE INF ###
tail -n +2 ${wswine_bundle}/share/wine/inf/osx-wine.inf \
  | grep -v '^;' \
  >> ${wswine_bundle}/share/wine/wine.inf
sed -i '' -e $'1s/^/\xef\xbb\xbf/' ${wswine_bundle}/share/wine/wine.inf

### REMOVE UNNECESSARY FILES ###
rm -f ${wswine_bundle}/bin/nihonshu
rm -r ${wswine_bundle}/share/wine/inf

### CREATE DISTFILE ###
mkdir -p "${proj_root}"/distfiles
tar cf - -C ${tempdir} wswine.bundle \
| /opt/local/bin/7z a -si "${proj_root}"/distfiles/ws_${wine_version}_nihonshu-${proj_version}.tar.7z

### CLOSING ###
rm -r ${tempdir}
unset wswine_bundle
unset tempdir
