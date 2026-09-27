@echo off
rem Builds the three Free Pascal / Lazarus packages of Report Manager.
rem Usage: build_fpc.bat            (uses C:\lazarus\lazbuild.exe)
rem        set LAZARUS_DIR=D:\lazarus & build_fpc.bat
rem
rem FPC 3.2.2 needs a second, incremental pass over reportman_rtl: the unit
rem cycle rpsection (implementation) -> rpsubreport -> rpsecutil -> rpsection
rem leaves rpsecutil.ppu with a stale interface checksum after a clean build,
rem and the packages that use reportman_rtl then fail with
rem "Can't find unit rpsecutil used by rpsubreport". Touching rpsecutil.pas
rem makes lazbuild recompile it (and its dependents) consistently. lazbuild
rem compares file ages with 2-second resolution, hence the wait before touching.
setlocal
set LAZBUILD=C:\lazarus\lazbuild.exe
if not "%LAZARUS_DIR%"=="" set LAZBUILD=%LAZARUS_DIR%\lazbuild.exe
if not exist "%LAZBUILD%" (
  echo Error: lazbuild not found at %LAZBUILD%
  exit /b 1
)
set ROOT=%~dp0..\..

echo Compiling reportman_rtl.lpk...
"%LAZBUILD%" --no-write-project "%ROOT%\packages\fpc\reportman_rtl.lpk" || goto fail
timeout /t 3 /nobreak >nul
copy /b "%ROOT%\rpsecutil.pas"+,, "%ROOT%\rpsecutil.pas" >nul
"%LAZBUILD%" --no-write-project "%ROOT%\packages\fpc\reportman_rtl.lpk" || goto fail

echo Compiling reportman_lcl.lpk...
"%LAZBUILD%" --no-write-project "%ROOT%\packages\fpc_lcl\reportman_lcl.lpk" || goto fail

echo Compiling reportman_designlcl.lpk...
"%LAZBUILD%" --no-write-project "%ROOT%\packages\fpc_lcl\reportman_designlcl.lpk" || goto fail

echo SUCCESS
exit /b 0

:fail
echo FAILED
exit /b 1
