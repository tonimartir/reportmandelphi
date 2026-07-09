@echo off
rem Build and run the real-world MyBase/MIDAS XML read test (Win32).
rem Reads every C:\data\xml\*.xml with our reader and compares to TClientDataSet.
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" >nul 2>&1
dcc32 -B xmlreadtest.dpr
if errorlevel 1 goto :eof
xmlreadtest.exe
