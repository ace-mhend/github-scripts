# ============================================
# Export Combined Copilot Metrics to Excel
# ============================================
# Combines user data with aggregate metrics
# Sorted by username
# Includes chat requests and lines of code
# ============================================

param(
    [string]$OutputDir = ".\output",
    [int]$DaysBack = 1
)

# Find the most recent combined files
$usersFile = Get-ChildItem "$OutputDir\combined_users_*.json" -File | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 -ExpandProperty FullName

$metricsFile = Get-ChildItem "$OutputDir\combined_metrics_*.json" -File | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 -ExpandProperty FullName

if (-not $usersFile -or -not (Test-Path $usersFile)) {
    Write-Error "No users JSON file found. Run fetch_combined_metrics.bat first."
    exit 1
}

if (-not $metricsFile -or -not (Test-Path $metricsFile)) {
    Write-Error "No metrics JSON file found. Run fetch_combined_metrics.bat first."
    exit 1
}

Write-Host "Processing users: $usersFile"
Write-Host "Processing metrics: $metricsFile"

# Load JSON data
$usersJson = Get-Content -Raw $usersFile | ConvertFrom-Json
$metricsJson = Get-Content -Raw $metricsFile | ConvertFrom-Json

$cutoffDate = (Get-Date).AddDays(-$DaysBack)

# ============================================
# Sheet 1: Users sorted by username with activity
# ============================================
$userData = $usersJson.seats | ForEach-Object {
    $lastActivity = if ($_.last_activity_at) { [datetime]$_.last_activity_at } else { $null }
    $lastAuth = if ($_.last_authenticated_at) { [datetime]$_.last_authenticated_at } else { $null }
    
    [PSCustomObject]@{
        Username = $_.assignee.login
        PlanType = $_.plan_type
        LastActivityAt = $lastActivity
        LastActivityEditor = $_.last_activity_editor
        LastAuthenticatedAt = $lastAuth
        CreatedAt = [datetime]$_.created_at
        ActiveInPeriod = if ($lastActivity -and $lastActivity -gt $cutoffDate) { "Yes" } else { "No" }
    }
} | Sort-Object Username

$activeUsers = $userData | Where-Object { $_.ActiveInPeriod -eq "Yes" }

Write-Host "Total users: $($userData.Count)"
Write-Host "Users active in past $DaysBack day(s): $($activeUsers.Count)"

# ============================================
# Sheet 2: Chat requests by day
# ============================================
$chatData = $metricsJson | ForEach-Object {
    $totalChats = 0
    $ideChatUsers = 0
    $dotcomChatUsers = 0
    
    # IDE Chat
    if ($_.copilot_ide_chat.editors) {
        foreach ($editor in $_.copilot_ide_chat.editors) {
            foreach ($model in $editor.models) {
                $totalChats += $model.total_chats
            }
        }
        $ideChatUsers = $_.copilot_ide_chat.total_engaged_users
    }
    
    # Dotcom Chat
    if ($_.copilot_dotcom_chat.models) {
        foreach ($model in $_.copilot_dotcom_chat.models) {
            $totalChats += $model.total_chats
        }
        $dotcomChatUsers = $_.copilot_dotcom_chat.total_engaged_users
    }
    
    [PSCustomObject]@{
        Date = $_.date
        TotalChatRequests = $totalChats
        IDEChatUsers = $ideChatUsers
        DotcomChatUsers = $dotcomChatUsers
        TotalActiveUsers = $_.total_active_users
        ChatsPerActiveUser = if ($_.total_active_users -gt 0) { [math]::Round($totalChats / $_.total_active_users, 1) } else { 0 }
    }
} | Sort-Object Date -Descending

# ============================================
# Sheet 3: Lines of code by day and language
# ============================================
# Field mappings:
#   loc_added_sum         = total_code_lines_accepted (lines inserted via Tab/Apply)
#   loc_suggested_to_add  = total_code_lines_suggested (ghost text shown)
#   loc_deleted_sum       = Not available in API (placeholder)
#   agent_edit            = Not available in API (placeholder)
# ============================================
$linesData = @()
foreach ($day in $metricsJson) {
    if ($day.copilot_ide_code_completions.editors) {
        foreach ($editor in $day.copilot_ide_code_completions.editors) {
            foreach ($model in $editor.models) {
                if ($model.languages) {
                    foreach ($lang in $model.languages) {
                        $linesData += [PSCustomObject]@{
                            Date = $day.date
                            Editor = $editor.name
                            Language = $lang.name
                            loc_added_sum = $lang.total_code_lines_accepted
                            loc_deleted_sum = $null  # Not available in API
                            loc_suggested_to_add_sum = $lang.total_code_lines_suggested
                            agent_edit = $null  # Not available in API
                            Acceptances = $lang.total_code_acceptances
                            Suggestions = $lang.total_code_suggestions
                            AcceptanceRate = if ($lang.total_code_suggestions -gt 0) { 
                                [math]::Round(($lang.total_code_acceptances / $lang.total_code_suggestions) * 100, 1) 
                            } else { 0 }
                        }
                    }
                }
            }
        }
    }
}
$linesData = $linesData | Sort-Object @{Expression="Date"; Descending=$true}, @{Expression="Language"; Descending=$false}

# ============================================
# Sheet 4: Summary - totals for period
# ============================================
$periodStart = ($metricsJson | Sort-Object date | Select-Object -First 1).date
$periodEnd = ($metricsJson | Sort-Object date -Descending | Select-Object -First 1).date

$totalChats = ($chatData | Measure-Object -Property TotalChatRequests -Sum).Sum
$totalLocAdded = ($linesData | Measure-Object -Property loc_added_sum -Sum).Sum
$totalLocSuggested = ($linesData | Measure-Object -Property loc_suggested_to_add_sum -Sum).Sum
$avgChatsPerUser = [math]::Round(($chatData | Measure-Object -Property ChatsPerActiveUser -Average).Average, 1)

$summary = @(
    [PSCustomObject]@{ Metric = "Period Start"; Value = $periodStart }
    [PSCustomObject]@{ Metric = "Period End"; Value = $periodEnd }
    [PSCustomObject]@{ Metric = "Total Seats"; Value = $usersJson.total_seats }
    [PSCustomObject]@{ Metric = "Active Users (past $DaysBack day)"; Value = $activeUsers.Count }
    [PSCustomObject]@{ Metric = "Total Chat Requests"; Value = $totalChats }
    [PSCustomObject]@{ Metric = "Avg Chats Per Active User"; Value = $avgChatsPerUser }
    [PSCustomObject]@{ Metric = "loc_added_sum (Lines Accepted)"; Value = $totalLocAdded }
    [PSCustomObject]@{ Metric = "loc_deleted_sum (Lines Removed)"; Value = "N/A - Not in API" }
    [PSCustomObject]@{ Metric = "loc_suggested_to_add_sum (Ghost Text)"; Value = $totalLocSuggested }
    [PSCustomObject]@{ Metric = "agent_edit (Agent Mode Lines)"; Value = "N/A - Not in API" }
    [PSCustomObject]@{ Metric = "Overall Acceptance Rate"; Value = if ($totalLocSuggested -gt 0) { "$([math]::Round(($totalLocAdded / $totalLocSuggested) * 100, 1))%" } else { "0%" } }
)

# ============================================
# Export to Excel
# ============================================
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$excelPath = "$OutputDir\copilot_combined_metrics_$timestamp.xlsx"

$summary | Export-Excel -Path $excelPath -WorksheetName 'Summary' -AutoSize -TableStyle Medium2
$activeUsers | Export-Excel -Path $excelPath -WorksheetName 'ActiveUsers' -AutoSize -TableStyle Medium6 -Append
$chatData | Export-Excel -Path $excelPath -WorksheetName 'ChatRequests' -AutoSize -TableStyle Medium9 -Append
$linesData | Export-Excel -Path $excelPath -WorksheetName 'LinesOfCode' -AutoSize -TableStyle Medium4 -Append

Write-Host ""
Write-Host "Excel file created: $excelPath"
Write-Host ""
Write-Host "Sheets included:"
Write-Host "  1. Summary - Key metrics overview"
Write-Host "  2. ActiveUsers - Users sorted by username"
Write-Host "  3. ChatRequests - Chat requests by active user per day"
Write-Host "  4. LinesOfCode - Lines of code accepted/suggested by language"

# Open the file
Start-Process $excelPath
