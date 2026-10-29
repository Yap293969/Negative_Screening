@echo off
rem Installs the Windows Task Scheduler task "Negative Screening - Weekly":
rem every Monday at 09:00 (or the time given, e.g. install_scheduled_task.bat 08:30),
rem runs as soon as possible after a missed Monday, never two runs at once,
rem starts NegativeScreening.exe --scheduled in this folder. Logs: logs\
cd /d "%~dp0"
set "TIME_ARG=09:00"
if not "%~1"=="" set "TIME_ARG=%~1"

if exist "NegativeScreening.exe" (
    ".\NegativeScreening.exe" --install-task --task-time %TIME_ARG%
) else if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" negative_screening.py --install-task --task-time %TIME_ARG%
) else (
    python negative_screening.py --install-task --task-time %TIME_ARG%
)
set "RESULT=%ERRORLEVEL%"
if "%RESULT%"=="0" (echo The weekly task is installed.) else (echo The weekly task was NOT installed.)
pause
exit /b %RESULT%
