# REQUIRED VARIABLES
: ${PROJECTROOT:?}
: ${PROJECT_VERSION:?}
: ${WINE_VERSION:?}
: ${DISTFILE:?}

### CREATE WORKING DIRECTORY ###
tempdir=`mktemp -d -t $$`
tar xf ${DISTFILE} -C ${tempdir}
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
mkdir -p ${PROJECTROOT}/distfiles
tar cf - -C ${tempdir} wswine.bundle \
  | /opt/local/bin/7z a -si ${PROJECTROOT}/distfiles/ws_${WINE_VERSION}_nihonshu-${PROJECT_VERSION}.tar.7z

### CLOSING ###
rm -r ${tempdir}
unset wswine_bundle
unset tempdir
