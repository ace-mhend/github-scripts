@echo off
setlocal enabledelayedexpansion
REM ============================================
REM Summarize Copilot Usage Data
REM ============================================
REM Parses JSON output and displays summary stats
REM Usage: summarize_usage.bat [json_file]
REM ============================================

set "JSON_FILE=%~1"

if "%JSON_FILE%"=="" (
    echo Usage: %~nx0 [json_file]
    exit /b 1
)

if not exist "%JSON_FILE%" (
    echo ERROR: File not found: %JSON_FILE%
    exit /b 1
)

echo.
echo ============================================
echo Usage Summary for: %~nx1
echo ============================================

REM Count total suggestions
set "SUGGESTIONS=0"
for /f %%a in ('findstr /c:"total_suggestions_count" "%JSON_FILE%" 2^>nul ^| find /c /v ""') do set "SUGGESTIONS=%%a"

REM Count total acceptances
set "ACCEPTANCES=0"
for /f %%a in ('findstr /c:"total_acceptances_count" "%JSON_FILE%" 2^>nul ^| find /c /v ""') do set "ACCEPTANCES=%%a"

REM Count total active users
set "ACTIVE_USERS=0"
for /f %%a in ('findstr /c:"total_active_users" "%JSON_FILE%" 2^>nul ^| find /c /v ""') do set "ACTIVE_USERS=%%a"

REM Count days of data
set "DAYS=0"
for /f %%a in ('findstr /c:"\"day\"" "%JSON_FILE%" 2^>nul ^| find /c /v ""') do set "DAYS=%%a"

REM Count breakdown entries
set "BREAKDOWN_ENTRIES=0"
for /f %%a in ('findstr /c:"\"breakdown\"" "%JSON_FILE%" 2^>nul ^| find /c /v ""') do set "BREAKDOWN_ENTRIES=%%a"

echo.
echo Metrics Overview:
echo   Days of data:        %DAYS%
echo   Suggestion entries:  %SUGGESTIONS%
echo   Acceptance entries:  %ACCEPTANCES%
echo   Active user entries: %ACTIVE_USERS%
echo   Breakdown sections:  %BREAKDOWN_ENTRIES%
echo.

REM Extract and display language breakdown if available
echo Checking for language breakdown...
findstr /c:"\"language\"" "%JSON_FILE%" >nul 2>&1
if not errorlevel 1 (
    echo.
    echo Languages detected in usage data:
    for /f "tokens=2 delims=:," %%a in ('findstr /c:"\"language\"" "%JSON_FILE%"') do (
        echo   - %%~a
    )
)

REM Extract and display editor breakdown if available
findstr /c:"\"editor\"" "%JSON_FILE%" >nul 2>&1
if not errorlevel 1 (
    echo.
    echo Editors detected in usage data:
    for /f "tokens=2 delims=:," %%a in ('findstr /c:"\"editor\"" "%JSON_FILE%"') do (
        echo   - %%~a
    )
)

echo.
echo ============================================
echo Full JSON output saved to: %JSON_FILE%
echo ============================================

endlocal
exit /b 0
