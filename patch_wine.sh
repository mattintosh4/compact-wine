sed "s|@WINE_VERSION@|$(cat VERSION)|
     s|@UNAME@|$(uname -v)|
     s|@TRIPLE@|$TRIPLE|
     s|@CONFIGURE_ARGS@|${configure_args[*]}|" <<\! | patch -Np1
diff --git a/loader/main.c b/loader/main.c
index ac67290..7cdafeb 100644
--- a/loader/main.c
+++ b/loader/main.c
@@ -87,6 +87,11 @@ static inline void reserve_area( void *addr, size_t size )
 static void check_command_line( int argc, char *argv[] )
 {
     static const char usage[] =
+        "@WINE_VERSION@  Nihonshu binary edition\n"
+        "  Build: @UNAME@\n"
+        "  Target: @TRIPLE@\n"
+        "  Configured with: @CONFIGURE_ARGS@\n"
+        "\n"
         "Usage: wine PROGRAM [ARGUMENTS...]   Run the specified program\n"
         "       wine --help                   Display this help and exit\n"
         "       wine --version                Output version information and exit";
!

sed -i '' '/^wine_fn_config_program/s/,installbin,manpage//' configure
sed -i '' "/^wine-installed: main.o wine_info.plist/{n;s|\$| -Wl,-rpath,$XLIBDIR -Wl,-rpath,/usr/lib|;}" configure

sed -i '' '/{IDS_SHV_COLUMN1,/s/[0-9][0-9]}/30}/' dlls/shell32/recyclebin.c dlls/shell32/shfldr_*.c

cp -p programs/regedit/folder.ico     dlls/shell32/folder.ico
cp -p programs/regedit/folder.ico     dlls/shell32/mydocs.ico
cp -p programs/regedit/folderopen.ico dlls/shell32/folder_open.ico
