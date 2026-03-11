@echo off
setlocal enabledelayedexpansion
REM ============================================
REM Export Copilot Usage to CSV
REM ============================================
REM Converts JSON usage data to CSV format
REM Usage: export_to_csv.bat [json_file] [output_csv]
REM ============================================

set "JSON_FILE=%~1"
set "CSV_FILE=%~2"

if "%JSON_FILE%"=="" (
    echo Usage: %~nx0 [json_file] [output_csv]
    echo.
    echo Converts Copilot usage JSON data to CSV format.
    exit /b 1
)

if not exist "%JSON_FILE%" (
    echo ERROR: File not found: %JSON_FILE%
    exit /b 1
)

if "%CSV_FILE%"=="" (
    set "CSV_FILE=%JSON_FILE:.json=.csv%"
)

echo ============================================
echo Exporting Usage Data to CSV
echo ============================================
echo Input:  %JSON_FILE%
echo Output: %CSV_FILE%
echo.

REM Write CSV header
echo day,total_suggestions_count,total_acceptances_count,total_lines_suggested,total_lines_accepted,total_active_users,total_chat_acceptances,total_chat_turns,total_active_chat_users> "%CSV_FILE%"

REM Check if PowerShell is available for better JSON parsing
where powershell >nul 2>&1
if errorlevel 1 (
    echo WARNING: PowerShell not found. Using basic parsing.
    goto BASIC_PARSE
)

REM Use PowerShell for proper JSON parsing
powershell -NoProfile -Command ^
    "$json = Get-Content -Path '%JSON_FILE%' -Raw | ConvertFrom-Json; ^
    foreach ($item in $json) { ^
        $day = $item.day; ^
        $suggestions = if ($item.total_suggestions_count) { $item.total_suggestions_count } else { 0 }; ^
        $acceptances = if ($item.total_acceptances_count) { $item.total_acceptances_count } else { 0 }; ^
        $linesSuggested = if ($item.total_lines_suggested) { $item.total_lines_suggested } else { 0 }; ^
        $linesAccepted = if ($item.total_lines_accepted) { $item.total_lines_accepted } else { 0 }; ^
        $activeUsers = if ($item.total_active_users) { $item.total_active_users } else { 0 }; ^
        $chatAcceptances = if ($item.total_chat_acceptances) { $item.total_chat_acceptances } else { 0 }; ^
        $chatTurns = if ($item.total_chat_turns) { $item.total_chat_turns } else { 0 }; ^
        $chatUsers = if ($item.total_active_chat_users) { $item.total_active_chat_users } else { 0 }; ^
        Write-Output \"$day,$suggestions,$acceptances,$linesSuggested,$linesAccepted,$activeUsers,$chatAcceptances,$chatTurns,$chatUsers\"; ^
    }" >> "%CSV_FILE%"

if errorlevel 1 (
    echo ERROR: PowerShell parsing failed.
    goto BASIC_PARSE
)

goto DONE

:BASIC_PARSE
echo Using basic text parsing (limited accuracy)...
REM Basic parsing fallback - extracts key values using findstr
for /f "tokens=2 delims=:," %%a in ('findstr /c:"\"day\"" "%JSON_FILE%"') do (
    set "DAY=%%~a"
    echo !DAY!,0,0,0,0,0,0,0,0>> "%CSV_FILE%"
)

:DONE
echo.
echo CSV export complete!
echo Output saved to: %CSV_FILE%
echo.

REM Count rows
set "ROW_COUNT=0"
for /f %%a in ('find /c /v "" ^<"%CSV_FILE%"') do set /a ROW_COUNT=%%a-1
echo Total data rows: %ROW_COUNT%

endlocal
exit /b 0
