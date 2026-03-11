@echo off
REM ============================================
REM GitHub Copilot Metrics - Configuration File
REM ============================================

REM GitHub Personal Access Token (requires admin:enterprise or admin:org scope)
REM Set this as an environment variable - DO NOT commit tokens!
if not defined GITHUB_TOKEN (
    echo ERROR: GITHUB_TOKEN environment variable is not set.
    echo Set it with: set GITHUB_TOKEN=your_token_here
    exit /b 1
)

REM Enterprise slug (for enterprise-level queries)
set "ENTERPRISE=ace-hardware"

REM Organization name (for org-level queries)
set "ORG=AceHdw"

REM API Base URL (GitHub.com or GitHub Enterprise Server)
set "API_BASE_URL=https://api.github.com"

REM Default date range (ISO 8601 format: YYYY-MM-DD)
REM Leave empty to use API defaults
set "START_DATE="
set "END_DATE="

REM Granularity: hour or day
set "GRANULARITY=day"

REM Pagination settings
set "PER_PAGE=100"

REM Output directory for results
set "OUTPUT_DIR=%~dp0output"

REM Create output directory if it doesn't exist
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo Configuration loaded successfully.
