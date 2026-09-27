@echo off
rem Regenerates ..\golden\json_delphi.txt with Delphi's System.JSON.
rem Needs Delphi (rsvars.bat); set BDS_RSVARS to use another version.
setlocal
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not "%BDS_RSVARS%"=="" set RSVARS=%BDS_RSVARS%
call "%RSVARS%" || goto fail
cd /d "%~dp0"
set ROOT=..\..\..\..
if not exist out mkdir out
dcc32 -B -Q -CC -NSSystem;Winapi -U"%ROOT%" -I"%ROOT%" -E"out" -NU"out" JsonGolden.dpr || goto fail
if not exist ..\golden mkdir ..\golden
out\JsonGolden.exe ..\golden\json_delphi.txt || goto fail
echo SUCCESS
exit /b 0
:fail
echo FAILED
exit /b 1
