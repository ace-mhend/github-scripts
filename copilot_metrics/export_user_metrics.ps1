# ============================================
# Export User Metrics to Excel (Past Day)
# ============================================
# Filters for users active in the past day
# Sorted by username
# ============================================

param(
    [string]$InputFile,
    [string]$OutputDir = ".\output"
)

# Find the most recent user metrics file if not specified
if (-not $InputFile) {
    $InputFile = Get-ChildItem "$OutputDir\user_metrics_*.json" -File | 
        Where-Object { $_.Name -notmatch '\.page\d+$' } |
        Sort-Object LastWriteTime -Descending | 
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $InputFile -or -not (Test-Path $InputFile)) {
    Write-Error "No user metrics JSON file found. Run fetch_user_metrics.bat first."
    exit 1
}

Write-Host "Processing: $InputFile"

# Load JSON data
$json = Get-Content -Raw $InputFile | ConvertFrom-Json

$yesterday = (Get-Date).AddDays(-1)

# Extract user data, filter for past day activity, sort by username
$allUsers = $json.seats | ForEach-Object {
    $lastActivity = if ($_.last_activity_at) { [datetime]$_.last_activity_at } else { $null }
    $lastAuth = if ($_.last_authenticated_at) { [datetime]$_.last_authenticated_at } else { $null }
    
    [PSCustomObject]@{
        Username = $_.assignee.login
        PlanType = $_.plan_type
        LastActivityAt = $lastActivity
        LastActivityEditor = $_.last_activity_editor
        LastAuthenticatedAt = $lastAuth
        CreatedAt = [datetime]$_.created_at
        ActiveInPastDay = if ($lastActivity -and $lastActivity -gt $yesterday) { "Yes" } else { "No" }
    }
}

# Filter for past day and sort by username
$pastDayUsers = $allUsers | Where-Object { $_.ActiveInPastDay -eq "Yes" } | Sort-Object Username

Write-Host "Total users: $($allUsers.Count)"
Write-Host "Users active in past day: $($pastDayUsers.Count)"

# Export to Excel
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$excelPath = "$OutputDir\user_metrics_pastday_$timestamp.xlsx"

$pastDayUsers | Export-Excel -Path $excelPath -WorksheetName 'ActiveUsers' -AutoSize -TableStyle Medium2

Write-Host "Excel file created: $excelPath"

# Open the file
Start-Process $excelPath
