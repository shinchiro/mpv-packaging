@echo OFF
:: expand searching for 'updater.ps1' file in same folder as mpv.exe too
if exist "%~dp0\installer\updater.ps1" (
    set updater_script="%~dp0\installer\updater.ps1"
) else (
    set updater_script="%~dp0\updater.ps1"
)
powershell -noprofile -nologo -noexit -executionpolicy bypass -File %updater_script%
