@echo off
setlocal
title F-15C SIT (WW) - install
if exist "%~dp0installer\f15sit_install.ps1" goto have_files
echo.
echo  Unzip the whole folder first, then run INSTALL.bat from there.
echo.
pause
exit /b 1
:have_files
echo.
echo  F-15C SIT (WW) add-on for the Flaming Cliffs F-15C
echo.
echo  This folder must be in  Saved Games\DCS\Mods\tech\F-15C SIT (WW)
echo  Close DCS before continuing.
echo  Run this again after every DCS update or repair (it puts the controls back).
echo.
pause
rem options are passed on, e.g. INSTALL.bat -DcsPath "D:\DCS World"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\f15sit_install.ps1" %*
echo.
pause
