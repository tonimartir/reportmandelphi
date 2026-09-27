@echo off
rem Builds the three Free Pascal / Lazarus packages of Report Manager.
rem Usage: build_fpc.bat            (uses C:\lazarus\lazbuild.exe)
rem        build_fpc.bat clean      (rebuilds reportman_rtl from scratch)
rem        set LAZARUS_DIR=D:\lazarus & build_fpc.bat
rem
rem Each package is compiled once, as the Lazarus IDE / Online Package Manager
rem does: a clean or incremental build of reportman_rtl leaves consistent PPUs
rem (see the FPC 3.2.2 note in the interface uses of rpsection.pas).
rem Use "clean" to rebuild reportman_rtl from scratch, e.g. if FPC ever reports
rem "Compilation raised exception internally" after an incremental build.
setlocal
set LAZBUILD=C:\lazarus\lazbuild.exe
if not "%LAZARUS_DIR%"=="" set LAZBUILD=%LAZARUS_DIR%\lazbuild.exe
if not exist "%LAZBUILD%" (
  echo Error: lazbuild not found at %LAZBUILD%
  exit /b 1
)
set ROOT=%~dp0..\..
set RTLCLEAN=
if /i "%~1"=="clean" set RTLCLEAN=-B

echo Compiling reportman_rtl.lpk...
"%LAZBUILD%" %RTLCLEAN% --no-write-project "%ROOT%\packages\fpc\reportman_rtl.lpk" || goto fail

echo Compiling reportman_lcl.lpk...
"%LAZBUILD%" --no-write-project "%ROOT%\packages\fpc_lcl\reportman_lcl.lpk" || goto fail

echo Compiling reportman_designlcl.lpk...
"%LAZBUILD%" --no-write-project "%ROOT%\packages\fpc_lcl\reportman_designlcl.lpk" || goto fail

echo SUCCESS
exit /b 0

:fail
echo FAILED
exit /b 1
