W_SYSTEM32='C:\windows\system32\'
W_TEMP='C:\windows\temp\'

#-------------------------------------------------------------------------------

w_cmd()
{
    wine ${W_SYSTEM32}cmd.exe "$@"
}
w_regedit()
{
    wine ${W_SYSTEM32}regedit.exe "$@"
}
w_regsvr32()
{
    wine ${W_SYSTEM32}regsvr32.exe "$@"
}
w_rundll32()
{
    wine ${W_SYSTEM32}rundll32.exe setupapi,InstallHinfSection DefaultInstall 128 '\\?\'unix"$1"
}
w_wineboot()
{
    wine ${W_SYSTEM32}wineboot.exe "$@"
}

#-------------------------------------------------------------------------------

w_override()
{
    case $1 in
    b  ) set -- $2 builtin        ;;
    b,n) set -- $2 builtin,native ;;
    n  ) set -- $2 native         ;;
    n,b) set -- $2 native,builtin ;;
    '' ) set -- $2 ''             ;;
    *  ) return 1                 ;;
    esac

    echo overriding $1 to $2

    w_regedit - <<!
[HKEY_CURRENT_USER\\Software\\wine\\DllOverrides]
"$1"="$2"
!
}

w_remove()
{
    w_cmd /C del "$@"
}

w_winver()
{
    case $1 in
    # $1: CSDVersion
    # $2: CurrentBuildNumber
    # $3: CurrentVersion
    # $4: ProductName
    # $5: CSDVersion (hex)
    2k) set -- 'Service Pack 4' 2195 5.0 'Microsoft Windows 2000' 00000400 ;;
    xp) set -- 'Service Pack 3' 2600 5.1 'Microsoft Windows XP'   00000300 ;;
    * ) return 1 ;;
    esac

    w_regedit - <<!
[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion]
"CSDVersion"="$1"
"CurrentBuildNumber"="$2"
"CurrentVersion"="$3"
"ProductName"="$4"

[HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Windows]
"CSDVersion"=dword:$5
!
}

#-------------------------------------------------------------------------------

vcrun2005=/usr/local/src/nihonshu/rsrc/vcrun2005sp1_jun2011/vcredist_x86.EXE
vcrun2008=/usr/local/src/nihonshu/rsrc/vcrun2008sp1_jun2011/vcredist_x86.exe
vcrun2010=/usr/local/src/nihonshu/rsrc/vcrun2010sp1_aug2011/vcredist_x86.exe
dx9_feb2010=$HOME/.cache/winetricks/directx9/directx_feb2010_redist.exe
dx9_jun2010=$HOME/.cache/winetricks/directx9/directx_Jun2010_redist.exe

load_vcrun2005()
{
    echo "Starting Visual C Runtime 2005 setup..."

    w_remove    ${W_SYSTEM32}atl80.dll \
                ${W_SYSTEM32}msvcm80.dll \
                ${W_SYSTEM32}msvcp80.dll \
                ${W_SYSTEM32}msvcr80.dll \
                ${W_SYSTEM32}vcomp.dll

    w_override n atl80
    w_override n msvcm80
    w_override n msvcp80
    w_override n msvcr80
    w_override n vcomp

    w_winver 2k
    wine $vcrun2005 /q
    w_winver xp
}
load_vcrun2008()
{
    echo "Starting Visual C Runtime 2008 setup..."

    w_remove    ${W_SYSTEM32}atl90.dll \
                ${W_SYSTEM32}msvcm90.dll \
                ${W_SYSTEM32}msvcp90.dll \
                ${W_SYSTEM32}msvcr90.dll \
                ${W_SYSTEM32}vcomp90.dll

    w_override n atl90
    w_override n msvcm90
    w_override n msvcp90
    w_override n msvcr90
    w_override n vcomp90

    w_winver 2k
    wine $vcrun2008 /q
    w_winver xp
}
load_vcrun2010()
{
    echo "Starting Visual C Runtime 2010 setup..."

    w_remove    ${W_SYSTEM32}atl100.dll \
                ${W_SYSTEM32}msvcp100.dll \
                ${W_SYSTEM32}msvcr100.dll \
                ${W_SYSTEM32}vcomp100.dll

    w_override n atl100
    w_override n msvcp100
    w_override n msvcr100
    w_override n vcomp100

    wine $vcrun2010 /q
}
load_dx9_feb2010()
{
    echo "Starting DirectX 9 setup..."
    w_cmd /c del %winsysdir%\\d3dim.dll
    w_cmd /c del %winsysdir%\\dpnaddr.dll
    w_cmd /c del %winsysdir%\\dpnlobby.dll
    w_cmd /c del %winsysdir%\\joy.cpl

    wine $dx9_feb2010 /Q /C /T:${W_TEMP}directx9\\feb2010
    wine $dx9_jun2010 /Q /C /T:${W_TEMP}directx9\\jun2010

    wine cabarc.exe X ${W_TEMP}directx9\\feb2010\\dxnt.cab          ${W_TEMP}\\directx9\\feb2010\\dxnt\\
    wine rundll32.exe setupapi,InstallHinfSection WINXP_INSTALL 128 ${W_TEMP}\\directx9\\feb2010\\dxnt\\dxxp.inf
    wine rundll32.exe setupapi,InstallHinfSection WINXP_INSTALL 128 ${W_TEMP}\\directx9\\feb2010\\dxnt\\dxntunp.inf

    set -- \
        amstream \
        devenum \
        dxdiag.exe \
        dxdiagn \
        qcap \
        qedit \
        quartz
    for f
    {
        w_override n $f
    }
    w_regsvr32 \
        amstream.dll \
        devenum.dll \
        dxdiagn.dll \
        qasf.dll \
        qcap.dll \
        qdv.dll \
        qdvd.dll \
        qedit.dll \
        quartz.dll

    wine Z:/tmp/directx9/feb2010/dxsetup.exe /silent
    wine Z:/tmp/directx9/jun2010/dxsetup.exe /silent
}

load_vcrun2005
load_vcrun2008
load_vcrun2010
load_dx9_feb2010
