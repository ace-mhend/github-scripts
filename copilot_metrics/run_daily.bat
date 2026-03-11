@echo off
REM ============================================
REM Daily Copilot Metrics Collection
REM ============================================
REM Fetches metrics and exports to Excel
REM Saves to monthly folder with date-based name
REM ============================================

cd /d "%~dp0"

REM Load config
call config.bat

REM Get current date components
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set "YEAR=%datetime:~0,4%"
set "MONTH=%datetime:~4,2%"
set "DAY=%datetime:~6,2%"
set "MONTHFOLDER=%OUTPUT_DIR%\%YEAR%-%MONTH%"

REM Create month folder if needed
if not exist "%MONTHFOLDER%" mkdir "%MONTHFOLDER%"

echo ============================================
echo Daily Copilot Metrics Collection
echo ============================================
echo Date: %YEAR%-%MONTH%-%DAY%
echo Organization: %ORG%
echo Output folder: %MONTHFOLDER%
echo.

REM Fetch combined metrics
echo [1/2] Fetching metrics from GitHub API...
call fetch_combined_metrics.bat %ORG% 1

REM Export to Excel in month folder
echo [2/2] Exporting to Excel...
powershell -ExecutionPolicy Bypass -Command ^
  "$usersFile = Get-ChildItem '%OUTPUT_DIR%\combined_users_*.json' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName; " ^
  "$metricsFile = Get-ChildItem '%OUTPUT_DIR%\combined_metrics_*.json' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName; " ^
  "$usersJson = Get-Content -Raw $usersFile | ConvertFrom-Json; " ^
  "$metricsJson = Get-Content -Raw $metricsFile | ConvertFrom-Json; " ^
  "$cutoffDate = (Get-Date).AddDays(-1); " ^
  "$userData = $usersJson.seats | ForEach-Object { $lastActivity = if ($_.last_activity_at) { [datetime]$_.last_activity_at } else { $null }; $lastAuth = if ($_.last_authenticated_at) { [datetime]$_.last_authenticated_at } else { $null }; [PSCustomObject]@{ Username = $_.assignee.login; PlanType = $_.plan_type; LastActivityAt = $lastActivity; LastActivityEditor = $_.last_activity_editor; LastAuthenticatedAt = $lastAuth; CreatedAt = [datetime]$_.created_at; ActiveInPeriod = if ($lastActivity -and $lastActivity -gt $cutoffDate) { 'Yes' } else { 'No' } } } | Sort-Object Username; " ^
  "$activeUsers = $userData | Where-Object { $_.ActiveInPeriod -eq 'Yes' }; " ^
  "$chatData = $metricsJson | ForEach-Object { $totalChats = 0; $ideChatUsers = 0; $dotcomChatUsers = 0; if ($_.copilot_ide_chat.editors) { foreach ($editor in $_.copilot_ide_chat.editors) { foreach ($model in $editor.models) { $totalChats += $model.total_chats } }; $ideChatUsers = $_.copilot_ide_chat.total_engaged_users }; if ($_.copilot_dotcom_chat.models) { foreach ($model in $_.copilot_dotcom_chat.models) { $totalChats += $model.total_chats }; $dotcomChatUsers = $_.copilot_dotcom_chat.total_engaged_users }; [PSCustomObject]@{ Date = $_.date; TotalChatRequests = $totalChats; IDEChatUsers = $ideChatUsers; DotcomChatUsers = $dotcomChatUsers; TotalActiveUsers = $_.total_active_users; ChatsPerActiveUser = if ($_.total_active_users -gt 0) { [math]::Round($totalChats / $_.total_active_users, 1) } else { 0 } } } | Sort-Object Date -Descending; " ^
  "$linesData = @(); foreach ($day in $metricsJson) { if ($day.copilot_ide_code_completions.editors) { foreach ($editor in $day.copilot_ide_code_completions.editors) { foreach ($model in $editor.models) { if ($model.languages) { foreach ($lang in $model.languages) { $linesData += [PSCustomObject]@{ Date = $day.date; Editor = $editor.name; Language = $lang.name; loc_added_sum = $lang.total_code_lines_accepted; loc_deleted_sum = $null; loc_suggested_to_add_sum = $lang.total_code_lines_suggested; agent_edit = $null; Acceptances = $lang.total_code_acceptances; Suggestions = $lang.total_code_suggestions; AcceptanceRate = if ($lang.total_code_suggestions -gt 0) { [math]::Round(($lang.total_code_acceptances / $lang.total_code_suggestions) * 100, 1) } else { 0 } } } } } } } }; " ^
  "$linesData = $linesData | Sort-Object @{Expression='Date'; Descending=$true}, @{Expression='Language'; Descending=$false}; " ^
  "$periodStart = ($metricsJson | Sort-Object date | Select-Object -First 1).date; " ^
  "$periodEnd = ($metricsJson | Sort-Object date -Descending | Select-Object -First 1).date; " ^
  "$totalChatsSum = ($chatData | Measure-Object -Property TotalChatRequests -Sum).Sum; " ^
  "$totalLocAdded = ($linesData | Measure-Object -Property loc_added_sum -Sum).Sum; " ^
  "$totalLocSuggested = ($linesData | Measure-Object -Property loc_suggested_to_add_sum -Sum).Sum; " ^
  "$avgChatsPerUser = [math]::Round(($chatData | Measure-Object -Property ChatsPerActiveUser -Average).Average, 1); " ^
  "$summary = @([PSCustomObject]@{ Metric = 'Period Start'; Value = $periodStart }, [PSCustomObject]@{ Metric = 'Period End'; Value = $periodEnd }, [PSCustomObject]@{ Metric = 'Total Seats'; Value = $usersJson.total_seats }, [PSCustomObject]@{ Metric = 'Active Users (past 1 day)'; Value = $activeUsers.Count }, [PSCustomObject]@{ Metric = 'Total Chat Requests'; Value = $totalChatsSum }, [PSCustomObject]@{ Metric = 'Avg Chats Per Active User'; Value = $avgChatsPerUser }, [PSCustomObject]@{ Metric = 'loc_added_sum (Lines Accepted)'; Value = $totalLocAdded }, [PSCustomObject]@{ Metric = 'loc_deleted_sum (Lines Removed)'; Value = 'N/A - Not in API' }, [PSCustomObject]@{ Metric = 'loc_suggested_to_add_sum (Ghost Text)'; Value = $totalLocSuggested }, [PSCustomObject]@{ Metric = 'agent_edit (Agent Mode Lines)'; Value = 'N/A - Not in API' }, [PSCustomObject]@{ Metric = 'Overall Acceptance Rate'; Value = if ($totalLocSuggested -gt 0) { \"$([math]::Round(($totalLocAdded / $totalLocSuggested) * 100, 1))%%\" } else { '0%%' } }); " ^
  "$excelPath = '%MONTHFOLDER%\copilot_metrics_%YEAR%-%MONTH%-%DAY%.xlsx'; " ^
  "$summary | Export-Excel -Path $excelPath -WorksheetName 'Summary' -AutoSize -TableStyle Medium2; " ^
  "$activeUsers | Export-Excel -Path $excelPath -WorksheetName 'ActiveUsers' -AutoSize -TableStyle Medium6 -Append; " ^
  "$chatData | Export-Excel -Path $excelPath -WorksheetName 'ChatRequests' -AutoSize -TableStyle Medium9 -Append; " ^
  "$linesData | Export-Excel -Path $excelPath -WorksheetName 'LinesOfCode' -AutoSize -TableStyle Medium4 -Append; " ^
  "Write-Host 'Excel saved: ' $excelPath"

echo.
echo ============================================
echo Daily Collection Complete
echo ============================================
