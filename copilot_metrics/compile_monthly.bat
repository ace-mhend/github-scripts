@echo off
REM ============================================
REM Compile Monthly Copilot Metrics
REM ============================================
REM Run at end of each month to compile daily
REM spreadsheets into monthly summary
REM ============================================

cd /d "%~dp0"

REM Get previous month if running on 1st of month
for /f "tokens=1-3 delims=/" %%a in ("%date%") do (
    set "DAY=%%b"
)

REM Run the PowerShell compilation script
powershell -ExecutionPolicy Bypass -File "%~dp0compile_monthly.ps1"

echo.
echo Monthly compilation complete.
pause
