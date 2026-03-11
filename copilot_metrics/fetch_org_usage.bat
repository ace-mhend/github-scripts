@echo off
setlocal enabledelayedexpansion
REM ============================================
REM Fetch Copilot Usage for Single Organization
REM ============================================
REM GET /orgs/{org}/copilot/usage
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

REM Validate org
if "%ORG%"=="your-org-name" (
    echo ERROR: Please set ORG in config.bat or pass as argument.
    echo Usage: %~nx0 [org-name]
    exit /b 1
)

REM Build API endpoint
set "ENDPOINT=%API_BASE_URL%/orgs/%ORG%/copilot/usage"

REM Build query parameters
set "PARAMS="

if defined START_DATE (
    if "!PARAMS!"=="" (
        set "PARAMS=?since=%START_DATE%"
    ) else (
        set "PARAMS=!PARAMS!&since=%START_DATE%"
    )
)

if defined END_DATE (
    if "!PARAMS!"=="" (
        set "PARAMS=?until=%END_DATE%"
    ) else (
        set "PARAMS=!PARAMS!&until=%END_DATE%"
    )
)

if defined GRANULARITY (
    if "!PARAMS!"=="" (
        set "PARAMS=?granularity=%GRANULARITY%"
    ) else (
        set "PARAMS=!PARAMS!&granularity=%GRANULARITY%"
    )
)

if defined PER_PAGE (
    if "!PARAMS!"=="" (
        set "PARAMS=?per_page=%PER_PAGE%"
    ) else (
        set "PARAMS=!PARAMS!&per_page=%PER_PAGE%"
    )
)

REM Generate timestamp for output filename
for /f "tokens=1-6 delims=/:. " %%a in ("%date% %time%") do (
    set "TIMESTAMP=%%a%%b%%c_%%d%%e%%f"
)

set "OUTPUT_FILE=%OUTPUT_DIR%\org_usage_%ORG%_%TIMESTAMP%.json"
set "TEMP_FILE=%OUTPUT_DIR%\temp_response.json"
set "ALL_DATA_FILE=%OUTPUT_DIR%\org_usage_%ORG%_all_%TIMESTAMP%.json"

echo ============================================
echo Fetching Copilot Usage for Organization: %ORG%
echo ============================================
echo Endpoint: %ENDPOINT%!PARAMS!
echo Output: %OUTPUT_FILE%
echo.

REM Initialize pagination
set "PAGE=1"
set "HAS_MORE=true"
set "TOTAL_RECORDS=0"

REM Initialize combined output file
echo [ > "%ALL_DATA_FILE%"
set "FIRST_PAGE=true"

:FETCH_LOOP
echo Fetching page %PAGE%...

REM Build paginated URL
if "!PARAMS!"=="" (
    set "PAGE_URL=%ENDPOINT%?page=!PAGE!&per_page=%PER_PAGE%"
) else (
    set "PAGE_URL=%ENDPOINT%!PARAMS!&page=!PAGE!"
)

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
    echo ERROR: API returned an error message. Check your credentials and org name.
    del "%TEMP_FILE%" 2>nul
    exit /b 1
)

REM Count records in this page
for /f %%a in ('findstr /c:"day" "%TEMP_FILE%" ^| find /c /v ""') do set "PAGE_RECORDS=%%a"
set /a TOTAL_RECORDS+=PAGE_RECORDS

echo   Retrieved approximately !PAGE_RECORDS! records from page !PAGE!

REM Copy current page to individual file
copy "%TEMP_FILE%" "%OUTPUT_DIR%\org_usage_%ORG%_page!PAGE!_%TIMESTAMP%.json" >nul

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
call "%~dp0summarize_usage.bat" "%OUTPUT_DIR%\org_usage_%ORG%_page1_%TIMESTAMP%.json"

endlocal
exit /b 0
