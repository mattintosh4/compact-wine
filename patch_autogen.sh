#!/bin/ksh -e

PATH=`/usr/bin/getconf PATH`

PROJECTROOT=${1:?}

set -- $PROJECTROOT/patch_archive/`date +%Y%m%d-%H%M%S`
mkdir -p $1
cd $1
csplit -sk $PROJECTROOT/wine___all.diff '%diff --git%' '/diff --git/' '{100}' || :
set -- xx*
for f
{
    ! grep -sq "^Binary files" $f || { rm $f; continue; }
    set -- `awk 'NR == 1 { sub("^a/", "wine___", $3); gsub("/", "__", $3); print $3; }' $f`
    mv $f $1.diff
}
