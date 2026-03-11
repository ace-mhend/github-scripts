@echo off
setlocal enabledelayedexpansion
REM ============================================
REM Fetch Copilot Usage for Multiple Orgs
REM ============================================
REM Iterates through a list of organizations
REM ============================================

REM Load configuration
call "%~dp0config.bat"

REM Organizations list file
set "ORGS_FILE=%~dp0orgs_list.txt"

if not exist "%ORGS_FILE%" (
    echo ERROR: Organizations list file not found: %ORGS_FILE%
    echo.
    echo Please create %ORGS_FILE% with one organization name per line.
    echo Example:
    echo   org-name-1
    echo   org-name-2
    echo   org-name-3
    exit /b 1
)

echo ============================================
echo Fetching Copilot Usage for Multiple Organizations
echo ============================================
echo.

set "ORG_COUNT=0"
set "SUCCESS_COUNT=0"
set "FAIL_COUNT=0"

for /f "usebackq tokens=* delims=" %%o in ("%ORGS_FILE%") do (
    set "CURRENT_ORG=%%o"
    
    REM Skip empty lines and comments
    if not "!CURRENT_ORG!"=="" (
        echo !CURRENT_ORG! | findstr /b "#" >nul 2>&1
        if errorlevel 1 (
            set /a ORG_COUNT+=1
            echo.
            echo [!ORG_COUNT!] Processing organization: !CURRENT_ORG!
            echo --------------------------------------------
            
            call "%~dp0fetch_org_usage.bat" "!CURRENT_ORG!"
            
            if errorlevel 1 (
                set /a FAIL_COUNT+=1
                echo WARNING: Failed to fetch data for !CURRENT_ORG!
            ) else (
                set /a SUCCESS_COUNT+=1
            )
        )
    )
)

echo.
echo ============================================
echo Batch Processing Complete!
echo ============================================
echo Total organizations processed: %ORG_COUNT%
echo Successful: %SUCCESS_COUNT%
echo Failed: %FAIL_COUNT%
echo.
echo Output files saved to: %OUTPUT_DIR%
echo ============================================

endlocal
exit /b 0
