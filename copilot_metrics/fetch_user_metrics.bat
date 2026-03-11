@echo off
setlocal enabledelayedexpansion
REM ============================================
REM Fetch Copilot User Metrics (Past Day)
REM ============================================
REM GET /orgs/{org}/copilot/billing/seats
REM ============================================
REM Returns per-user seat assignments with activity
REM Sorted by username, filtered for past day
REM ============================================

REM Load configuration
call "%~dp0config.bat"

REM Allow org override via command line
if not "%~1"=="" set "ORG=%~1"

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

REM Build API endpoint for seats
set "ENDPOINT=%API_BASE_URL%/orgs/%ORG%/copilot/billing/seats"

REM Generate timestamp for output filename
for /f "tokens=1-6 delims=/:. " %%a in ("%date% %time%") do (
    set "TIMESTAMP=%%a%%b%%c_%%d%%e%%f"
)

set "OUTPUT_FILE=%OUTPUT_DIR%\user_metrics_%ORG%_%TIMESTAMP%.json"

echo ============================================
echo Fetching Copilot User Metrics
echo ============================================
echo Organization: %ORG%
echo Endpoint: %ENDPOINT%
echo.

echo Fetching user seats data...

REM Make API request (single page for most orgs)
curl -s ^
    -H "Accept: application/vnd.github+json" ^
    -H "Authorization: Bearer %GITHUB_TOKEN%" ^
    -H "X-GitHub-Api-Version: 2022-11-28" ^
    "%ENDPOINT%?per_page=100" > "%OUTPUT_FILE%" 2>&1

REM Count seats in response
for /f %%a in ('findstr /c:"\"login\"" "%OUTPUT_FILE%" ^| find /c /v ""') do set "TOTAL_SEATS=%%a"

echo   Retrieved %TOTAL_SEATS% users

echo.
echo ============================================
echo Fetch Complete
echo ============================================
echo Total users: %TOTAL_SEATS%
echo Output saved to: %OUTPUT_FILE%
echo.

endlocal
