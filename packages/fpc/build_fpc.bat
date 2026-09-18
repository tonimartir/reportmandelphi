@echo off
set LAZBUILD="C:\lazarus\lazbuild.exe"
if not exist %LAZBUILD% (
  echo Error: lazbuild not found at %LAZBUILD%
  exit /b 1
)

echo Compiling reportman_rtl.lpk...
%LAZBUILD% --build-mode=Debug reportman_rtl.lpk
if errorlevel 1 (
  echo FAILED compiling reportman_rtl.lpk
  exit /b 1
)
echo SUCCESS
