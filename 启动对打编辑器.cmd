@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0output/combat-feel-runtime/start-editor.ps1" %*
if errorlevel 1 pause
