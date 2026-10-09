@echo off
chcp 65001 > nul
setlocal
cd /d "%~dp0"

python docker\build_androidc.py %*
exit /b %ERRORLEVEL%
