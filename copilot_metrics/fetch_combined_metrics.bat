@echo off
setlocal enabledelayedexpansion
REM ============================================
REM Fetch Combined Copilot Metrics
REM ============================================
REM Fetches both user seats and detailed metrics
REM Parameters:
REM   %1 - Organization name (optional, uses config)
REM   %2 - Days back to fetch (optional, default 1)
REM ============================================

REM Load configuration
call "%~dp0config.bat"

REM Parse arguments
if not "%~1"=="" set "ORG=%~1"
set "DAYS_BACK=1"
if not "%~2"=="" set "DAYS_BACK=%~2"

REM Check for required tools
where curl >nul 2>&1
if errorlevel 1 (
    echo ERROR: curl is required but not found in PATH.
    exit /b 1
)

REM Validate token
if "%GITHUB_TOKEN%"=="your_github_token_here" (
    echo ERROR: Please set GITHUB_TOKEN in config.bat or as environment variable.
    exit /b 1
)

REM Generate timestamp for output filename
for /f "tokens=1-6 delims=/:. " %%a in ("%date% %time%") do (
    set "TIMESTAMP=%%a%%b%%c_%%d%%e%%f"
)

set "USERS_FILE=%OUTPUT_DIR%\combined_users_%ORG%_%TIMESTAMP%.json"
set "METRICS_FILE=%OUTPUT_DIR%\combined_metrics_%ORG%_%TIMESTAMP%.json"

echo ============================================
echo Fetching Combined Copilot Metrics
echo ============================================
echo Organization: %ORG%
echo Days Back: %DAYS_BACK%
echo.

REM Fetch user seats
echo [1/2] Fetching user seats...
set "SEATS_ENDPOINT=%API_BASE_URL%/orgs/%ORG%/copilot/billing/seats"
curl -s ^
    -H "Accept: application/vnd.github+json" ^
    -H "Authorization: Bearer %GITHUB_TOKEN%" ^
    -H "X-GitHub-Api-Version: 2022-11-28" ^
    "%SEATS_ENDPOINT%?per_page=100" > "%USERS_FILE%" 2>&1

for /f %%a in ('findstr /c:"\"login\"" "%USERS_FILE%" ^| find /c /v ""') do set "USER_COUNT=%%a"
echo   Retrieved %USER_COUNT% users

REM Fetch detailed metrics
echo [2/2] Fetching detailed metrics...
set "METRICS_ENDPOINT=%API_BASE_URL%/orgs/%ORG%/copilot/metrics"
curl -s ^
    -H "Accept: application/vnd.github+json" ^
    -H "Authorization: Bearer %GITHUB_TOKEN%" ^
    -H "X-GitHub-Api-Version: 2022-11-28" ^
    "%METRICS_ENDPOINT%?per_page=100" > "%METRICS_FILE%" 2>&1

for /f %%a in ('findstr /c:"\"date\"" "%METRICS_FILE%" ^| find /c /v ""') do set "DAYS_COUNT=%%a"
echo   Retrieved %DAYS_COUNT% days of metrics

echo.
echo ============================================
echo Fetch Complete
echo ============================================
echo Users file: %USERS_FILE%
echo Metrics file: %METRICS_FILE%
echo.
echo Run export_combined_metrics.ps1 to generate Excel report.
echo.

endlocal
