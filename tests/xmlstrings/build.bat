@echo off
rem Deep string-encoding investigation + reader/writer verification against a
rem real TClientDataSet (Win32). Self-contained: generates its own data.
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" >nul 2>&1
dcc32 -B strtest.dpr
if errorlevel 1 goto :eof
strtest.exe
