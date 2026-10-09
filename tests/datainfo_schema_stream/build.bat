@echo off
rem Builds the test of the schema of a dataset (HubSchemaId, SchemaName) in the
rem XML, text and binary formats of a report, without a database (Delphi, Win32).
rem The Lazarus build is test_datainfo_schema_stream.lpi (lazbuild).
setlocal

set DCC_ROOT=C:\Program Files (x86)\Embarcadero\Studio\37.0
set DCC32="%DCC_ROOT%\bin\dcc32.exe"
set RPROOT=..\..
set NS=System;System.Win;Winapi;Vcl;Vcl.Imaging;Xml;Data;Data.Win;Datasnap;Datasnap.Win;Web;Soap;Bde

cd /d "%~dp0"
if not exist bin_x86 mkdir bin_x86
if not exist dcu_x86 mkdir dcu_x86

%DCC32% -B -CC -DDEBUG;UNICODE -E.\bin_x86 -NU.\dcu_x86 -U%RPROOT% -I%RPROOT% -R%RPROOT% -NS%NS% test_datainfo_schema_stream.dpr
if errorlevel 1 (
  echo BUILD FAILED
  exit /b 1
)
echo Build OK.
endlocal
