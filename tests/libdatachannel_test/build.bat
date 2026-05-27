@echo off
setlocal

set DCC_ROOT=C:\Program Files (x86)\Embarcadero\Studio\37.0
set DCC32="%DCC_ROOT%\bin\dcc32.exe"
set DCC64="%DCC_ROOT%\bin\dcc64.exe"

rem Reportman repo root holds rplibdatachannel.pas and rpconf.inc.
set RPROOT=..\..

rem Standard Delphi RTL namespaces (the .dpr uses Winapi.Windows /
rem System.SysUtils explicitly, but rplibdatachannel.pas uses bare
rem Windows / SysUtils so we need the namespace prefix list).
set NS=System;Winapi;Vcl;System.Win

if not exist bin_x86 mkdir bin_x86
if not exist bin_x64 mkdir bin_x64

echo --------------------------------------------
echo  Compiling x86 (dcc32)
echo --------------------------------------------
%DCC32% -B -CC -E.\bin_x86 -U%RPROOT% -I%RPROOT% -NS%NS% test_libdc.dpr
if errorlevel 1 (
  echo BUILD FAILED for x86
  exit /b 1
)

echo --------------------------------------------
echo  Compiling x64 (dcc64)
echo --------------------------------------------
%DCC64% -B -CC -E.\bin_x64 -U%RPROOT% -I%RPROOT% -NS%NS% test_libdc.dpr
if errorlevel 1 (
  echo BUILD FAILED for x64
  exit /b 1
)

echo.
echo Build OK.
echo   bin_x86\test_libdc.exe
echo   bin_x64\test_libdc.exe
echo.
endlocal
