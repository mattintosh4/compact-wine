sed "s|@WINE_VERSION@|$(cat VERSION)|
     s|@UNAME@|$(uname -v)|
     s|@TRIPLE@|$__TRIPLE__|
     s|@CONFIGURE_ARGS@|${args[*]}|
     s|@DATE@|`date +%F`|" <<\! | patch -Np1
diff --git a/loader/main.c b/loader/main.c
index ac67290..7cdafeb 100644
--- a/loader/main.c
+++ b/loader/main.c
@@ -87,6 +87,11 @@ static inline void reserve_area( void *addr, size_t size )
 static void check_command_line( int argc, char *argv[] )
 {
     static const char usage[] =
+        "@WINE_VERSION@  Nihonshu binary edition (@DATE@)\n"
+        "  Build: @UNAME@\n"
+        "  Target: @TRIPLE@\n"
+        "  Configured with: @CONFIGURE_ARGS@\n"
+        "\n"
         "Usage: wine PROGRAM [ARGUMENTS...]   Run the specified program\n"
         "       wine --help                   Display this help and exit\n"
         "       wine --version                Output version information and exit";
!

sed -i '' -f /dev/fd/0 configure <<!
/^wine_fn_config_program/s/,installbin,manpage//
/^wine-installed: main.o wine_info.plist/{
    n
    s|\$| -Wl,-rpath,/usr/lib|
}
!

sed -i '' -f /dev/fd/0 \
dlls/shell32/recyclebin.c \
dlls/shell32/shfldr_*.c <<!
/{IDS_SHV_COLUMN1,/s/[0-9][0-9]}/30}/
!

/opt/local/bin/xz -dc ${SRCROOT}/gnome-icon-theme-3.12.0.tar.xz \
| tar xf - -C ${TMPDIR}

#places/user-home.png
#places/user-bookmarks.png

icon_pairs=(
    places/folder.png,folder.ico
    places/folder-documents.png,mydocs.ico
    places/user-trash.png,trash_file.ico
    places/user-desktop.png,desktop.ico
    status/folder-open.png,folder_open.ico
    devices/drive-harddisk.png,drive.ico
    devices/drive-optical.png,cdrom.ico
    devices/drive-removable-media.png,floppy.ico
    devices/computer.png,mycomputer.ico
    mimetypes/text-x-generic.png,document.ico
)

for f in ${icon_pairs[@]}
{
    ifs=${IFS} IFS=,
    set -- ${f}
    IFS=${ifs}

    /opt/local/bin/convert \
        ${TMPDIR}/gnome-icon-theme-3.12.0/gnome/{\
16x16,\
24x24,\
32x32,\
48x48}/${1} dlls/shell32/${2}
}
