#SingleInstance force
#Persistent

^Tab::
If (IsWindowVisible("windowsterminal.exe"))
    WinHide ahk_exe windowsterminal.exe
Else
    WinShow ahk_exe windowsterminal.exe
    WinActivate ahk_exe windowsterminal.exe
Return

IsWindowVisible(pProcessName) {
	DetectHiddenWindows, On
	static WS_VISIBLE := 0x10000000
	WinGet, Style, Style, % "ahk_exe " pProcessName
	return (Style & WS_VISIBLE)
}