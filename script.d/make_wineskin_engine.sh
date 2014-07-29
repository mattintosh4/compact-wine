wswine_bundle=/tmp/wswine.bundle

# INIT
rm -rf ${wswine_bundle}

# DUPLICATE
ditto ${INSTALL_PREFIX} ${wswine_bundle}

# REMOVE UNNECESSARIES
rm -f ${wswine_bundle}/bin/nihonshu

# UPDATE INF
tail -n +2 ${wswine_bundle}/share/wine/inf/osx-wine.inf \
  | grep -v '^;' \
  >> ${wswine_bundle}/share/wine/wine.inf
sed -i '' -e $'1s/^/\xef\xbb\xbf/' ${wswine_bundle}/share/wine/wine.inf
rm -r ${wswine_bundle}/share/wine/inf

# CREATE DISTFILE
set -- \
  `cut -d' ' -f3 ${TMPDIR}/wine/VERSION` \
  `sw_vers -productVersion | cut -d. -f-2` \
  `date +%Y%m%d`
mkdir -p ${PROJECTROOT}/distfiles
tar cf - -C /tmp wswine.bundle \
  | /opt/local/bin/7z a -si ${PROJECTROOT}/distfiles/wine-${1}_nihonshu_osx${2}_${3}.tar.7z

# REMOVE TEMPORARY FILE
rm -rf ${wswine_bundle}
