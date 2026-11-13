@echo off
setlocal
title F-15C SIT (WW) - uninstall
if exist "%~dp0installer\f15sit_install.ps1" goto have_files
echo.
echo  Unzip the whole folder first, then run UNINSTALL.bat from there.
echo.
pause
exit /b 1
:have_files
echo.
echo  Removes the F-15C SIT add-on's controls, its Export.lua line and its scripts.
echo  Close DCS before continuing.
echo.
pause
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\f15sit_install.ps1" -Uninstall %*
echo.
pause
