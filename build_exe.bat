@echo off
rem Builds dist\NegativeScreening.exe (one file, no console window) with PyInstaller and
rem copies it into this project folder, next to config\, data\, logs\ and reports\.
rem No passwords or configuration are packaged: config\ stays outside the exe and the
rem passwords stay in Windows Credential Manager or environment variables.
cd /d "%~dp0"
set "PY=python"
if exist ".venv\Scripts\python.exe" set "PY=.venv\Scripts\python.exe"

"%PY%" -m pip install -r requirements.txt -r requirements-build.txt
if errorlevel 1 exit /b 1

"%PY%" negative_screening.py --self-test all
if errorlevel 1 (
    echo Self-tests failed: the exe was not built.
    exit /b 1
)

"%PY%" -m PyInstaller --noconfirm --clean --onefile --windowed --name NegativeScreening ^
    --collect-data tzdata --specpath build negative_screening.py
if errorlevel 1 exit /b 1

copy /y "dist\NegativeScreening.exe" "NegativeScreening.exe" >nul
if errorlevel 1 exit /b 1
echo.
echo Built dist\NegativeScreening.exe and copied it to "%CD%\NegativeScreening.exe".
exit /b 0
