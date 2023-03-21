#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
SetTitleMatchMode, RegEx

; uninstalling part

ProgramFilesX86 := A_ProgramFiles . (A_PtrSize=8 ? " (x86)" : "")

winpcapUninstaller = %A_ProgramFiles%\WinPcap\Uninstall.exe
winpcapUninstallerx86 = %ProgramFilesX86%\WinPcap\Uninstall.exe

IfExist, %winpcapUninstaller%
{
	Run, %winpcapUninstaller%
	installed = 1
}
IfExist, %winpcapUninstallerx86%
{
	Run, %winpcapUninstallerx86%
	installed = 1
}
if (installed = 1)
{
	WinWait, WinPcap [\d\.]+ Uninstall,, 30
	IfWinExist
	{
		BlockInput, On
		Sleep, 250
		WinActivate
		Send, {Enter}
		BlockInput, Off
	}

	WinWait, WinPcap [\d\.]+ Uninstall, has been uninstalled, 30
		IfWinExist
		{
			BlockInput, On
			Sleep, 250
			WinActivate
			Send, {Enter}
			BlockInput, Off
		}
    exit
}

; installing part
winpcapInstaller = %1%
Run, %winpcapInstaller%

WinWait, WinPcap [\d\.]+ Setup,, 30

Loop, 3
{
	gosub, setupForward
}

WinWait, WinPcap [\d\.]+ Setup, has been installed, 30
	IfWinExist
	{
		BlockInput, On
		Sleep, 250
		WinActivate
		Send, {Enter}
		BlockInput, Off
	}

ExitApp

setupForward:
	IfWinExist
	{
		BlockInput, On
		Sleep, 250
		WinActivate
		Send, {Enter}
		BlockInput, Off
	}
return
