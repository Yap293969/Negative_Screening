@echo off
rem Removes the Windows Task Scheduler task "Negative Screening - Weekly".
rem Reports, logs, the database and saved passwords are not touched.
cd /d "%~dp0"
if exist "NegativeScreening.exe" (
    ".\NegativeScreening.exe" --uninstall-task
) else if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" negative_screening.py --uninstall-task
) else (
    python negative_screening.py --uninstall-task
)
set "RESULT=%ERRORLEVEL%"
if "%RESULT%"=="0" (echo Done.) else (echo The weekly task could NOT be removed.)
pause
exit /b %RESULT%
