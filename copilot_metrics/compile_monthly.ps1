# ============================================
# Compile Monthly Copilot Metrics
# ============================================
# Combines all daily spreadsheets into one
# monthly summary spreadsheet
# Run at end of each month
# ============================================

param(
    [string]$OutputDir = ".\output",
    [string]$Month = (Get-Date).ToString("yyyy-MM")
)

$monthFolder = Join-Path $OutputDir $Month

if (-not (Test-Path $monthFolder)) {
    Write-Error "Month folder not found: $monthFolder"
    exit 1
}

Write-Host "============================================"
Write-Host "Compiling Monthly Copilot Metrics"
Write-Host "============================================"
Write-Host "Month: $Month"
Write-Host "Folder: $monthFolder"
Write-Host ""

# Find all daily spreadsheets for the month
$dailyFiles = Get-ChildItem "$monthFolder\copilot_metrics_$Month-*.xlsx" -File | 
    Where-Object { $_.Name -notmatch '~\$' -and $_.Name -notmatch '_monthly_summary' } |
    Sort-Object Name

if ($dailyFiles.Count -eq 0) {
    Write-Error "No daily spreadsheets found in $monthFolder"
    exit 1
}

Write-Host "Found $($dailyFiles.Count) daily spreadsheet(s)"

# Initialize collections for combined data
$allSummary = @()
$allActiveUsers = @()
$allChatRequests = @()
$allLinesOfCode = @()

foreach ($file in $dailyFiles) {
    Write-Host "  Processing: $($file.Name)"
    
    # Extract date from filename
    $dateMatch = [regex]::Match($file.Name, '(\d{4}-\d{2}-\d{2})')
    $fileDate = if ($dateMatch.Success) { $dateMatch.Groups[1].Value } else { "Unknown" }
    
    try {
        # Import each sheet
        $summary = Import-Excel -Path $file.FullName -WorksheetName 'Summary' -ErrorAction SilentlyContinue
        $activeUsers = Import-Excel -Path $file.FullName -WorksheetName 'ActiveUsers' -ErrorAction SilentlyContinue
        $chatRequests = Import-Excel -Path $file.FullName -WorksheetName 'ChatRequests' -ErrorAction SilentlyContinue
        $linesOfCode = Import-Excel -Path $file.FullName -WorksheetName 'LinesOfCode' -ErrorAction SilentlyContinue
        
        # Add source date to summary rows
        if ($summary) {
            $summary | ForEach-Object {
                $_ | Add-Member -NotePropertyName "ReportDate" -NotePropertyValue $fileDate -Force
            }
            $allSummary += $summary
        }
        
        # Add source date to active users
        if ($activeUsers) {
            $activeUsers | ForEach-Object {
                $_ | Add-Member -NotePropertyName "ReportDate" -NotePropertyValue $fileDate -Force
            }
            $allActiveUsers += $activeUsers
        }
        
        # Chat requests already have dates
        if ($chatRequests) {
            $chatRequests | ForEach-Object {
                $_ | Add-Member -NotePropertyName "ReportDate" -NotePropertyValue $fileDate -Force
            }
            $allChatRequests += $chatRequests
        }
        
        # Lines of code already have dates
        if ($linesOfCode) {
            $linesOfCode | ForEach-Object {
                $_ | Add-Member -NotePropertyName "ReportDate" -NotePropertyValue $fileDate -Force
            }
            $allLinesOfCode += $linesOfCode
        }
    }
    catch {
        Write-Warning "Error processing $($file.Name): $_"
    }
}

# Create monthly summary statistics
Write-Host ""
Write-Host "Creating monthly summary..."

# Aggregate unique active users across the month
$uniqueActiveUsers = $allActiveUsers | 
    Where-Object { $_.ActiveInPeriod -eq "Yes" } |
    Select-Object -Property Username -Unique |
    Sort-Object Username

# Aggregate chat data (deduplicate by date)
$uniqueChatDays = $allChatRequests | 
    Select-Object Date, TotalChatRequests, IDEChatUsers, DotcomChatUsers, TotalActiveUsers, ChatsPerActiveUser -Unique |
    Sort-Object Date

# Aggregate lines of code (deduplicate by date + language)
$uniqueLinesData = $allLinesOfCode |
    Select-Object Date, Editor, Language, loc_added_sum, loc_deleted_sum, loc_suggested_to_add_sum, agent_edit, Acceptances, Suggestions, AcceptanceRate -Unique |
    Sort-Object Date, Language

# Calculate month totals
$monthTotalChats = ($uniqueChatDays | Measure-Object -Property TotalChatRequests -Sum).Sum
$monthLocAdded = ($uniqueLinesData | Measure-Object -Property loc_added_sum -Sum).Sum
$monthLocSuggested = ($uniqueLinesData | Measure-Object -Property loc_suggested_to_add_sum -Sum).Sum
$monthAvgActiveUsers = [math]::Round(($uniqueChatDays | Measure-Object -Property TotalActiveUsers -Average).Average, 1)

$monthlySummary = @(
    [PSCustomObject]@{ Metric = "Month"; Value = $Month }
    [PSCustomObject]@{ Metric = "Daily Reports Compiled"; Value = $dailyFiles.Count }
    [PSCustomObject]@{ Metric = "Unique Active Users"; Value = $uniqueActiveUsers.Count }
    [PSCustomObject]@{ Metric = "Avg Daily Active Users"; Value = $monthAvgActiveUsers }
    [PSCustomObject]@{ Metric = "Total Chat Requests"; Value = $monthTotalChats }
    [PSCustomObject]@{ Metric = "Total loc_added_sum"; Value = $monthLocAdded }
    [PSCustomObject]@{ Metric = "Total loc_suggested_to_add_sum"; Value = $monthLocSuggested }
    [PSCustomObject]@{ Metric = "Monthly Acceptance Rate"; Value = if ($monthLocSuggested -gt 0) { "$([math]::Round(($monthLocAdded / $monthLocSuggested) * 100, 1))%" } else { "0%" } }
)

# User activity summary for the month
$userMonthlySummary = $allActiveUsers |
    Group-Object Username |
    ForEach-Object {
        $activeDays = ($_.Group | Where-Object { $_.ActiveInPeriod -eq "Yes" }).Count
        $lastActivity = ($_.Group | Sort-Object LastActivityAt -Descending | Select-Object -First 1).LastActivityAt
        $lastEditor = ($_.Group | Sort-Object LastActivityAt -Descending | Select-Object -First 1).LastActivityEditor
        [PSCustomObject]@{
            Username = $_.Name
            DaysActive = $activeDays
            LastActivityAt = $lastActivity
            LastActivityEditor = $lastEditor
        }
    } | Sort-Object Username

# Export to monthly summary file
$monthlyExcelPath = Join-Path $monthFolder "copilot_metrics_${Month}_monthly_summary.xlsx"

$monthlySummary | Export-Excel -Path $monthlyExcelPath -WorksheetName 'MonthlySummary' -AutoSize -TableStyle Medium2
$userMonthlySummary | Export-Excel -Path $monthlyExcelPath -WorksheetName 'UserActivity' -AutoSize -TableStyle Medium6 -Append
$uniqueChatDays | Export-Excel -Path $monthlyExcelPath -WorksheetName 'DailyChatTotals' -AutoSize -TableStyle Medium9 -Append
$uniqueLinesData | Export-Excel -Path $monthlyExcelPath -WorksheetName 'DailyCodeTotals' -AutoSize -TableStyle Medium4 -Append

Write-Host ""
Write-Host "============================================"
Write-Host "Monthly Compilation Complete"
Write-Host "============================================"
Write-Host "Output: $monthlyExcelPath"
Write-Host ""
Write-Host "Sheets included:"
Write-Host "  1. MonthlySummary - Aggregated metrics for $Month"
Write-Host "  2. UserActivity - Per-user activity summary"
Write-Host "  3. DailyChatTotals - Chat requests by day"
Write-Host "  4. DailyCodeTotals - Lines of code by day"
Write-Host ""

# Open the file
Start-Process $monthlyExcelPath
