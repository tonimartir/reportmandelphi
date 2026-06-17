@echo off
rem Lanzador de doble clic para make-client-zip.ps1
rem Acepta los mismos parametros, p.ej.:  make-client-zip.cmd -Version 2.8.0.188
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make-client-zip.ps1" %*
exit /b %ERRORLEVEL%
