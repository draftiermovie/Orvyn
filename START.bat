@echo off
if exist "%~dp0AI-USB.next.exe" (
  copy /y "%~dp0AI-USB.next.exe" "%~dp0AI-USB.exe" >nul 2>nul
  if not errorlevel 1 del "%~dp0AI-USB.next.exe"
)
start "" "%~dp0dist\AI-USB.exe"
