@echo off
REM ============================================
REM Upload Copilot Metrics to SQL Database
REM ============================================
REM Uploads the latest JSON metrics files to SQL Server
REM Can be run independently or as part of run_daily.bat
REM ============================================

cd /d "%~dp0"

REM Load configuration
call config.bat

echo ============================================
echo Upload Copilot Metrics to SQL
echo ============================================
echo Organization: %ORG%
echo SQL Instance: %SQL_INSTANCE%
echo Database: %SQL_DATABASE%
echo Output Directory: %OUTPUT_DIR%
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0UploadMetricsToSQL.ps1" -OutputDir "%OUTPUT_DIR%" -Organization "%ORG%" -SqlInstance "%SQL_INSTANCE%" -Database "%SQL_DATABASE%"

echo.
echo Upload complete.
pause
