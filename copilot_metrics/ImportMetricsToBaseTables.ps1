<#
.SYNOPSIS
    Imports Copilot metrics JSON data to the existing base tables.

.DESCRIPTION
    Reads combined_metrics_*.json and combined_users_*.json files,
    transforms and inserts into base tables that the views query from:
    - CopilotDailySummary
    - CopilotChat
    - CopilotCodeCompletions
    - CopilotUserActivity
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "$PSScriptRoot\output",

    [Parameter(Mandatory = $false)]
    [string]$SqlInstance = 'OAKS0490.npcorp.npacehdw.com',

    [Parameter(Mandatory = $false)]
    [string]$Database = 'DevOpsUtilities'
)

Import-Module dbatools

$connectionString = "Server=$SqlInstance;Database=$Database;Integrated Security=True;TrustServerCertificate=True"

# Find latest JSON files
$metricsFile = Get-ChildItem -Path $OutputDir -Filter "combined_metrics_*.json" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 -ExpandProperty FullName

$usersFile = Get-ChildItem -Path $OutputDir -Filter "combined_users_*.json" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 -ExpandProperty FullName

Write-Host "============================================"
Write-Host "Import Copilot Metrics to Base Tables"
Write-Host "============================================"
Write-Host "Metrics file: $metricsFile"
Write-Host "Users file: $usersFile"
Write-Host ""

# Read JSON files
$metricsJson = Get-Content -Raw $metricsFile | ConvertFrom-Json
$usersJson = Get-Content -Raw $usersFile | ConvertFrom-Json

$timestamp = Get-Date

#region Import CopilotDailySummary
Write-Host "[1/4] Importing CopilotDailySummary..." -NoNewline

$dailySummary = @()
foreach ($day in $metricsJson) {
    $ideChatEngaged = if ($day.copilot_ide_chat) { $day.copilot_ide_chat.total_engaged_users } else { 0 }
    $dotcomChatEngaged = if ($day.copilot_dotcom_chat) { $day.copilot_dotcom_chat.total_engaged_users } else { 0 }
    $dotcomPREngaged = if ($day.copilot_dotcom_pull_requests) { $day.copilot_dotcom_pull_requests.total_engaged_users } else { 0 }
    $codeEngaged = if ($day.copilot_ide_code_completions) { $day.copilot_ide_code_completions.total_engaged_users } else { 0 }
    
    $dailySummary += [PSCustomObject]@{
        ReportDate = [datetime]$day.date
        Last_Updt_Tstamp = $timestamp
        TotalActiveUsers = $day.total_active_users
        TotalEngagedUsers = $day.total_engaged_users
        IDEChatEngagedUsers = $ideChatEngaged
        DotcomChatEngagedUsers = $dotcomChatEngaged
        DotcomPREngagedUsers = $dotcomPREngaged
        CodeCompletionsEngagedUsers = $codeEngaged
    }
}

if ($dailySummary.Count -gt 0) {
    # Delete existing data for these dates to avoid duplicates
    $dates = ($dailySummary | ForEach-Object { "'" + $_.ReportDate.ToString('yyyy-MM-dd') + "'" }) -join ','
    Invoke-DbaQuery -SqlInstance $connectionString -Query "DELETE FROM CopilotDailySummary WHERE ReportDate IN ($dates)"
    
    # Insert using individual SQL statements
    foreach ($row in $dailySummary) {
        $sql = @"
INSERT INTO CopilotDailySummary (ReportDate, Last_Updt_Tstamp, TotalActiveUsers, TotalEngagedUsers, IDEChatEngagedUsers, DotcomChatEngagedUsers, DotcomPREngagedUsers, CodeCompletionsEngagedUsers)
VALUES ('$($row.ReportDate.ToString('yyyy-MM-dd'))', '$($row.Last_Updt_Tstamp.ToString('yyyy-MM-dd HH:mm:ss'))', $($row.TotalActiveUsers), $($row.TotalEngagedUsers), $($row.IDEChatEngagedUsers), $($row.DotcomChatEngagedUsers), $($row.DotcomPREngagedUsers), $($row.CodeCompletionsEngagedUsers))
"@
        Invoke-DbaQuery -SqlInstance $connectionString -Query $sql
    }
    Write-Host " Done ($($dailySummary.Count) rows)" -ForegroundColor Green
}
#endregion

#region Import CopilotChat
Write-Host "[2/4] Importing CopilotChat..." -NoNewline

$chatData = @()
foreach ($day in $metricsJson) {
    # IDE Chat by editor
    if ($day.copilot_ide_chat.editors) {
        foreach ($editor in $day.copilot_ide_chat.editors) {
            foreach ($model in $editor.models) {
                $chatData += [PSCustomObject]@{
                    ReportDate = [datetime]$day.date
                    Editor = $editor.name
                    ModelName = $model.name
                    Last_Updt_Tstamp = $timestamp
                    TotalChats = $model.total_chats
                    EngagedUsers = $model.total_engaged_users
                    CopyEvents = $model.total_chat_copy_events
                    InsertionEvents = $model.total_chat_insertion_events
                }
            }
        }
    }
    
    # Dotcom Chat
    if ($day.copilot_dotcom_chat.models) {
        foreach ($model in $day.copilot_dotcom_chat.models) {
            $chatData += [PSCustomObject]@{
                ReportDate = [datetime]$day.date
                Editor = 'github.com'
                ModelName = $model.name
                Last_Updt_Tstamp = $timestamp
                TotalChats = $model.total_chats
                EngagedUsers = $model.total_engaged_users
                CopyEvents = $null
                InsertionEvents = $null
            }
        }
    }
}

if ($chatData.Count -gt 0) {
    $dates = ($chatData | Select-Object -Unique ReportDate | ForEach-Object { "'" + $_.ReportDate.ToString('yyyy-MM-dd') + "'" }) -join ','
    Invoke-DbaQuery -SqlInstance $connectionString -Query "DELETE FROM CopilotChat WHERE ReportDate IN ($dates)"
    
    foreach ($row in $chatData) {
        $copyEvents = if ($null -eq $row.CopyEvents) { "NULL" } else { $row.CopyEvents }
        $insertEvents = if ($null -eq $row.InsertionEvents) { "NULL" } else { $row.InsertionEvents }
        $sql = @"
INSERT INTO CopilotChat (ReportDate, Editor, ModelName, Last_Updt_Tstamp, TotalChats, EngagedUsers, CopyEvents, InsertionEvents)
VALUES ('$($row.ReportDate.ToString('yyyy-MM-dd'))', '$($row.Editor)', '$($row.ModelName)', '$($row.Last_Updt_Tstamp.ToString('yyyy-MM-dd HH:mm:ss'))', $($row.TotalChats), $($row.EngagedUsers), $copyEvents, $insertEvents)
"@
        Invoke-DbaQuery -SqlInstance $connectionString -Query $sql
    }
    Write-Host " Done ($($chatData.Count) rows)" -ForegroundColor Green
}
#endregion

#region Import CopilotCodeCompletions
Write-Host "[3/4] Importing CopilotCodeCompletions..." -NoNewline

$codeData = @()
foreach ($day in $metricsJson) {
    if ($day.copilot_ide_code_completions.editors) {
        foreach ($editor in $day.copilot_ide_code_completions.editors) {
            foreach ($model in $editor.models) {
                if ($model.languages) {
                    foreach ($lang in $model.languages) {
                        $codeData += [PSCustomObject]@{
                            ReportDate = [datetime]$day.date
                            Editor = $editor.name
                            ModelName = $model.name
                            CodeLanguage = $lang.name
                            Last_Updt_Tstamp = $timestamp
                            EngagedUsers = $lang.total_engaged_users
                            CodeAcceptances = $lang.total_code_acceptances
                            CodeSuggestions = $lang.total_code_suggestions
                            LinesAccepted = $lang.total_code_lines_accepted
                            LinesSuggested = $lang.total_code_lines_suggested
                        }
                    }
                }
            }
        }
    }
}

if ($codeData.Count -gt 0) {
    $dates = ($codeData | Select-Object -Unique ReportDate | ForEach-Object { "'" + $_.ReportDate.ToString('yyyy-MM-dd') + "'" }) -join ','
    Invoke-DbaQuery -SqlInstance $connectionString -Query "DELETE FROM CopilotCodeCompletions WHERE ReportDate IN ($dates)"
    
    foreach ($row in $codeData) {
        $sql = @"
INSERT INTO CopilotCodeCompletions (ReportDate, Editor, ModelName, CodeLanguage, Last_Updt_Tstamp, EngagedUsers, CodeAcceptances, CodeSuggestions, LinesAccepted, LinesSuggested)
VALUES ('$($row.ReportDate.ToString('yyyy-MM-dd'))', '$($row.Editor)', '$($row.ModelName)', '$($row.CodeLanguage -replace "'", "''")', '$($row.Last_Updt_Tstamp.ToString('yyyy-MM-dd HH:mm:ss'))', $($row.EngagedUsers), $($row.CodeAcceptances), $($row.CodeSuggestions), $($row.LinesAccepted), $($row.LinesSuggested))
"@
        Invoke-DbaQuery -SqlInstance $connectionString -Query $sql
    }
    Write-Host " Done ($($codeData.Count) rows)" -ForegroundColor Green
}
#endregion

#region Import CopilotUserActivity
Write-Host "[4/4] Importing CopilotUserActivity..." -NoNewline

$userData = @()
$cutoffDate = (Get-Date).AddDays(-1)
$reportDate = Get-Date

foreach ($seat in $usersJson.seats) {
    $lastActivity = if ($seat.last_activity_at) { [datetime]$seat.last_activity_at } else { $null }
    $activeInPastDay = if ($lastActivity -and $lastActivity -gt $cutoffDate) { 1 } else { 0 }
    
    $userData += [PSCustomObject]@{
        ReportDate = $reportDate
        Username = $seat.assignee.login
        Last_Updt_Tstamp = $timestamp
        PlanType = $seat.plan_type
        LastActivityAt = $lastActivity
        LastActivityEditor = $seat.last_activity_editor
        LastAuthenticatedAt = if ($seat.last_authenticated_at) { [datetime]$seat.last_authenticated_at } else { $null }
        CreatedAt = if ($seat.created_at) { [datetime]$seat.created_at } else { $null }
        ActiveInPastDay = $activeInPastDay
    }
}

if ($userData.Count -gt 0) {
    # Delete today's data to avoid duplicates
    $todayStr = $reportDate.ToString('yyyy-MM-dd')
    Invoke-DbaQuery -SqlInstance $connectionString -Query "DELETE FROM CopilotUserActivity WHERE ReportDate = '$todayStr'"
    
    foreach ($row in $userData) {
        $lastActivityAt = if ($null -eq $row.LastActivityAt) { "NULL" } else { "'$($row.LastActivityAt.ToString('yyyy-MM-dd HH:mm:ss'))'" }
        $lastActivityEditor = if ($null -eq $row.LastActivityEditor) { "NULL" } else { "'$($row.LastActivityEditor)'" }
        $lastAuthAt = if ($null -eq $row.LastAuthenticatedAt) { "NULL" } else { "'$($row.LastAuthenticatedAt.ToString('yyyy-MM-dd HH:mm:ss'))'" }
        $createdAt = if ($null -eq $row.CreatedAt) { "NULL" } else { "'$($row.CreatedAt.ToString('yyyy-MM-dd HH:mm:ss'))'" }
        
        $sql = @"
INSERT INTO CopilotUserActivity (ReportDate, Username, Last_Updt_Tstamp, PlanType, LastActivityAt, LastActivityEditor, LastAuthenticatedAt, CreatedAt, ActiveInPastDay)
VALUES ('$($row.ReportDate.ToString('yyyy-MM-dd'))', '$($row.Username)', '$($row.Last_Updt_Tstamp.ToString('yyyy-MM-dd HH:mm:ss'))', '$($row.PlanType)', $lastActivityAt, $lastActivityEditor, $lastAuthAt, $createdAt, $($row.ActiveInPastDay))
"@
        Invoke-DbaQuery -SqlInstance $connectionString -Query $sql
    }
    Write-Host " Done ($($userData.Count) rows)" -ForegroundColor Green
}
#endregion

Write-Host ""
Write-Host "============================================"
Write-Host "Import Complete" -ForegroundColor Cyan
Write-Host "============================================"
