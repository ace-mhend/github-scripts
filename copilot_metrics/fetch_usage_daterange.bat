@echo off
setlocal enabledelayedexpansion
REM ============================================
REM Fetch Copilot Usage with Custom Date Range
REM ============================================
REM Usage: fetch_usage_daterange.bat [enterprise|org] [name] [start_date] [end_date] [granularity]
REM Example: fetch_usage_daterange.bat org my-org 2026-01-01 2026-01-25 day
REM ============================================

REM Load configuration
call "%~dp0config.bat"

REM Parse command line arguments
set "SCOPE=%~1"
set "NAME=%~2"
set "START_DATE=%~3"
set "END_DATE=%~4"
set "GRANULARITY=%~5"

REM Validate arguments
if "%SCOPE%"=="" (
    echo Usage: %~nx0 [enterprise^|org] [name] [start_date] [end_date] [granularity]
    echo.
    echo Arguments:
    echo   scope       - "enterprise" or "org"
    echo   name        - Enterprise slug or organization name
    echo   start_date  - Start date in ISO format ^(YYYY-MM-DD^)
    echo   end_date    - End date in ISO format ^(YYYY-MM-DD^)
    echo   granularity - "hour" or "day" ^(optional, defaults to "day"^)
    echo.
    echo Example:
    echo   %~nx0 org my-organization 2026-01-01 2026-01-25 day
    echo   %~nx0 enterprise my-enterprise 2026-01-01 2026-01-25 hour
    exit /b 1
)

if not "%SCOPE%"=="enterprise" if not "%SCOPE%"=="org" (
    echo ERROR: Scope must be "enterprise" or "org"
    exit /b 1
)

if "%NAME%"=="" (
    echo ERROR: Name ^(enterprise slug or org name^) is required.
    exit /b 1
)

if "%START_DATE%"=="" (
    echo ERROR: Start date is required.
    exit /b 1
)

if "%END_DATE%"=="" (
    echo ERROR: End date is required.
    exit /b 1
)

if "%GRANULARITY%"=="" set "GRANULARITY=day"

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

REM Build API endpoint based on scope
if "%SCOPE%"=="enterprise" (
    set "ENDPOINT=%API_BASE_URL%/enterprises/%NAME%/copilot/usage"
) else (
    set "ENDPOINT=%API_BASE_URL%/orgs/%NAME%/copilot/usage"
)

REM Build query parameters
set "PARAMS=?since=%START_DATE%&until=%END_DATE%&granularity=%GRANULARITY%&per_page=%PER_PAGE%"

REM Generate timestamp for output filename
for /f "tokens=1-6 delims=/:. " %%a in ("%date% %time%") do (
    set "TIMESTAMP=%%a%%b%%c_%%d%%e%%f"
)

set "TEMP_FILE=%OUTPUT_DIR%\temp_response.json"
set "OUTPUT_PREFIX=%OUTPUT_DIR%\%SCOPE%_usage_%NAME%_%START_DATE%_to_%END_DATE%"

echo ============================================
echo Fetching Copilot Usage
echo ============================================
echo Scope: %SCOPE%
echo Name: %NAME%
echo Date Range: %START_DATE% to %END_DATE%
echo Granularity: %GRANULARITY%
echo Endpoint: %ENDPOINT%!PARAMS!
echo.

REM Initialize pagination
set "PAGE=1"
set "HAS_MORE=true"
set "TOTAL_RECORDS=0"

:FETCH_LOOP
echo Fetching page %PAGE%...

REM Build paginated URL
set "PAGE_URL=%ENDPOINT%!PARAMS!&page=!PAGE!"

REM Make API request with headers saved
curl -s -D "%OUTPUT_DIR%\headers.txt" ^
    -H "Accept: application/vnd.github+json" ^
    -H "Authorization: Bearer %GITHUB_TOKEN%" ^
    -H "X-GitHub-Api-Version: 2022-11-28" ^
    "%PAGE_URL%" > "%TEMP_FILE%"

if errorlevel 1 (
    echo ERROR: API request failed.
    exit /b 1
)

REM Check for API errors
findstr /c:"\"message\"" "%TEMP_FILE%" >nul 2>&1
if not errorlevel 1 (
    type "%TEMP_FILE%"
    echo.
    echo ERROR: API returned an error message.
    del "%TEMP_FILE%" 2>nul
    exit /b 1
)

REM Count records in this page
for /f %%a in ('findstr /c:"day" "%TEMP_FILE%" ^| find /c /v ""') do set "PAGE_RECORDS=%%a"
set /a TOTAL_RECORDS+=PAGE_RECORDS

echo   Retrieved approximately !PAGE_RECORDS! records from page !PAGE!

REM Copy current page to individual file
copy "%TEMP_FILE%" "%OUTPUT_PREFIX%_page!PAGE!_%TIMESTAMP%.json" >nul

REM Check for more pages via Link header
findstr /i "rel=\"next\"" "%OUTPUT_DIR%\headers.txt" >nul 2>&1
if errorlevel 1 (
    set "HAS_MORE=false"
) else (
    set /a PAGE+=1
)

if "!HAS_MORE!"=="true" goto FETCH_LOOP

REM Clean up
del "%TEMP_FILE%" 2>nul
del "%OUTPUT_DIR%\headers.txt" 2>nul

echo.
echo ============================================
echo Fetch Complete!
echo ============================================
echo Total pages fetched: %PAGE%
echo Approximate total records: %TOTAL_RECORDS%
echo Output files saved to: %OUTPUT_DIR%
echo.

REM Display summary
echo Generating summary...
call "%~dp0summarize_usage.bat" "%OUTPUT_PREFIX%_page1_%TIMESTAMP%.json"

endlocal
exit /b 0
