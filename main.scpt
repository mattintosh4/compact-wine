on main(argv)
	set temp to text item delimiters of AppleScript
	set text item delimiters of AppleScript to "/"
	set appname to item -1 of (every text item of (text 1 thru -2 of (POSIX path of (path to me))))
	set text item delimiters of AppleScript to temp

	set beginning of argv to quoted form of POSIX path of (path to me) & "Contents/Resources/wine/bin/nihonshu"
	if appname = "EasyWine64.app" then
		set beginning of argv to "WINEARCH=win64"
		set beginning of argv to "WINEPREFIX=$HOME/Library/Caches/Wine/prefixes/default64"
	else
		set beginning of argv to "WINEARCH=win32"
		if appname = "EasyWineRT.app" then
			set beginning of argv to "WINEPREFIX=$HOME/Library/Caches/Wine/prefixes/defaultRT"
		else
			set beginning of argv to "WINEPREFIX=$HOME/Library/Caches/Wine/prefixes/default"
		end if
	end if
	set beginning of argv to "WINEDEBUG=-all"
	set beginning of argv to "env"
	set end       of argv to ">/dev/null"
    set end       of argv to "2>&1"
    set end       of argv to "&"
    set end       of argv to "disown"
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
