@echo off
REM System Uptime Calculator Installer

setlocal
set "TARGETDIR=C:\ProgramData\SystemUptimeCalculator"
set "SOURCEDIR=%~dp0"
set "SCRIPTNAME=Systemuptimescript.ps1"

REM Create target directory if it doesn't exist
if not exist "%TARGETDIR%" mkdir "%TARGETDIR%"

REM Copy PowerShell script and any supporting files
copy "%SOURCEDIR%%SCRIPTNAME%" "%TARGETDIR%" /Y
REM (Add more copy commands here if you have more files to include)

REM Optionally create a shortcut on the desktop
set "SHORTCUT=%USERPROFILE%\Desktop\System Uptime Calculator.lnk"
if exist "%SHORTCUT%" del "%SHORTCUT%"
powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%SHORTCUT%'); $s.TargetPath = 'powershell.exe'; $s.Arguments = '-ExecutionPolicy Bypass -File \"%TARGETDIR%\%SCRIPTNAME%\"'; $s.Save()"

REM Inform the user
@echo Installation complete.
@echo Script installed to: %TARGETDIR%
@echo Shortcut created on Desktop.
@echo Output .csv will be in your Documents folder.
endlocal
pause