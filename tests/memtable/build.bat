@echo off
rem Build and run the MyBase DataPacket XML round-trip test (Win32).
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" >nul 2>&1
dcc32 -B memtabletest.dpr
if errorlevel 1 goto :eof
memtabletest.exe
