<#
.SYNOPSIS
    Estimates per-user Copilot metrics based on activity patterns.

.DESCRIPTION
    Since GitHub's Copilot API only provides aggregate metrics (not per-user),
    this script estimates individual user metrics by distributing org totals
    proportionally based on user activity patterns.

    Estimation methodology:
    1. Users with more recent activity get higher weights
    2. Users active within the period get higher weights than inactive users
    3. Org totals are distributed proportionally by weight

    NOTE: These are ESTIMATES only - actual per-user data is not available via API.

.PARAMETER OutputDir
    Directory containing the JSON files from fetch_combined_metrics.bat

.PARAMETER StartDate
    Start of the reporting period (default: 2026-03-01)

.PARAMETER EndDate
    End of the reporting period (default: today)

.PARAMETER OutputFile
    Path for the output CSV file

.EXAMPLE
    .\EstimatePerUserMetrics.ps1 -StartDate "2026-03-01" -EndDate "2026-03-19"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "$PSScriptRoot\output",

    [Parameter(Mandatory = $false)]
    [datetime]$StartDate = '2026-03-01',

    [Parameter(Mandatory = $false)]
    [datetime]$EndDate = (Get-Date),

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = "$PSScriptRoot\output\copilot_metrics_estimated_per_user.csv",

    [Parameter(Mandatory = $false)]
    [string]$SqlInstance = 'OAKS0490.npcorp.npacehdw.com',

    [Parameter(Mandatory = $false)]
    [string]$Database = 'DevOpsUtilities'
)

Import-Module dbatools -ErrorAction SilentlyContinue

Write-Host "============================================"
Write-Host "Copilot Per-User Metrics Estimator"
Write-Host "============================================"
Write-Host "Period: $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd'))"
Write-Host ""
Write-Host "NOTE: These are ESTIMATES based on activity patterns."
Write-Host "      Actual per-user data is not available via GitHub API."
Write-Host "============================================"
Write-Host ""

#region Load User Data
Write-Host "[1/5] Loading user data..." -NoNewline

$usersFile = Get-ChildItem -Path $OutputDir -Filter "combined_users_*.json" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 -ExpandProperty FullName

if (-not $usersFile) {
    Write-Host " ERROR: No user data file found" -ForegroundColor Red
    exit 1
}

$usersJson = Get-Content -Raw $usersFile | ConvertFrom-Json
Write-Host " Loaded $($usersJson.seats.Count) users" -ForegroundColor Green
#endregion

#region Get Org Totals from SQL
Write-Host "[2/5] Fetching org totals from SQL..." -NoNewline

$connectionString = "Server=$SqlInstance;Database=$Database;Integrated Security=True;TrustServerCertificate=True"
$startStr = $StartDate.ToString('yyyy-MM-dd')
$endStr = $EndDate.ToString('yyyy-MM-dd')

# Get chat totals
$chatTotals = Invoke-DbaQuery -SqlInstance $connectionString -Query @"
SELECT 
    ISNULL(SUM(TotalChats), 0) as TotalChats,
    ISNULL(SUM(CopyEvents), 0) as CopyEvents,
    ISNULL(SUM(InsertionEvents), 0) as InsertionEvents
FROM CopilotChat 
WHERE ReportDate >= '$startStr' AND ReportDate <= '$endStr'
"@

# Get code totals
$codeTotals = Invoke-DbaQuery -SqlInstance $connectionString -Query @"
SELECT 
    ISNULL(SUM(LinesAccepted), 0) as LinesAccepted,
    ISNULL(SUM(LinesSuggested), 0) as LinesSuggested,
    ISNULL(SUM(CodeAcceptances), 0) as CodeAcceptances,
    ISNULL(SUM(CodeSuggestions), 0) as CodeSuggestions
FROM CopilotCodeCompletions 
WHERE ReportDate >= '$startStr' AND ReportDate <= '$endStr'
"@

# Get daily active user counts
$dailyUsers = Invoke-DbaQuery -SqlInstance $connectionString -Query @"
SELECT 
    COUNT(DISTINCT ReportDate) as DaysInPeriod,
    ISNULL(SUM(TotalActiveUsers), 0) as TotalActiveUserDays,
    ISNULL(AVG(TotalActiveUsers), 0) as AvgDailyActiveUsers
FROM CopilotDailySummary 
WHERE ReportDate >= '$startStr' AND ReportDate <= '$endStr'
"@

Write-Host " Done" -ForegroundColor Green

Write-Host ""
Write-Host "   Org Totals for Period:"
Write-Host "   - Total Chats: $($chatTotals.TotalChats)"
Write-Host "   - Chat Copy Events: $($chatTotals.CopyEvents)"
Write-Host "   - Chat Insert Events: $($chatTotals.InsertionEvents)"
Write-Host "   - Lines Accepted: $($codeTotals.LinesAccepted)"
Write-Host "   - Code Acceptances: $($codeTotals.CodeAcceptances)"
Write-Host "   - Days in Period: $($dailyUsers.DaysInPeriod)"
Write-Host ""
#endregion

#region Calculate User Activity Weights
Write-Host "[3/5] Calculating activity weights..." -NoNewline

$periodDays = ($EndDate - $StartDate).Days + 1
$userWeights = @()
$totalWeight = 0

foreach ($seat in $usersJson.seats) {
    $username = $seat.assignee.login
    $lastActivity = if ($seat.last_activity_at) { [datetime]$seat.last_activity_at } else { $null }
    
    # Calculate weight based on activity recency
    $weight = 0
    $daysActive = 0
    $activityStatus = "Inactive"
    
    if ($lastActivity) {
        $daysSinceActivity = ($EndDate - $lastActivity).Days
        
        if ($lastActivity -ge $StartDate -and $lastActivity -le $EndDate) {
            # Active within period - higher weight for more recent activity
            # Weight formula: (periodDays - daysSinceActivity) / periodDays * activityMultiplier
            $activityMultiplier = 2.0  # Boost for being active in period
            $recencyScore = [Math]::Max(0, ($periodDays - $daysSinceActivity)) / $periodDays
            $weight = $recencyScore * $activityMultiplier
            
            # Estimate days active based on editor usage patterns
            $editor = $seat.last_activity_editor
            if ($editor -match "vscode|VisualStudio|JetBrains|Eclipse") {
                # IDE users likely use it regularly
                $daysActive = [Math]::Min($periodDays, [Math]::Max(1, $periodDays - $daysSinceActivity + 5))
            } else {
                $daysActive = [Math]::Max(1, [Math]::Round($periodDays * $recencyScore))
            }
            
            $activityStatus = "Active"
        }
        elseif ($daysSinceActivity -le 30) {
            # Recently active but not in period - lower weight
            $weight = 0.3
            $daysActive = 0
            $activityStatus = "RecentlyInactive"
        }
        else {
            # Not active recently
            $weight = 0.1
            $daysActive = 0
            $activityStatus = "Inactive"
        }
    }
    else {
        # No activity recorded
        $weight = 0.05
        $activityStatus = "NoActivity"
    }
    
    $userWeights += [PSCustomObject]@{
        Username = $username
        LastActivityAt = $lastActivity
        LastActivityEditor = $seat.last_activity_editor
        PlanType = $seat.plan_type
        ActivityStatus = $activityStatus
        EstimatedDaysActive = $daysActive
        Weight = $weight
    }
    
    $totalWeight += $weight
}

# Normalize weights to sum to 1
foreach ($user in $userWeights) {
    $user | Add-Member -NotePropertyName NormalizedWeight -NotePropertyValue ($user.Weight / $totalWeight) -Force
}

$activeUsers = ($userWeights | Where-Object { $_.ActivityStatus -eq "Active" }).Count
Write-Host " Done ($activeUsers active users)" -ForegroundColor Green
#endregion

#region Distribute Metrics Proportionally
Write-Host "[4/5] Estimating per-user metrics..." -NoNewline

$estimatedMetrics = @()

foreach ($user in $userWeights) {
    $w = $user.NormalizedWeight
    
    # Distribute org totals by normalized weight
    $estChats = [Math]::Round($chatTotals.TotalChats * $w, 0)
    $estCopyEvents = [Math]::Round($chatTotals.CopyEvents * $w, 0)
    $estInsertEvents = [Math]::Round($chatTotals.InsertionEvents * $w, 0)
    $estLinesAccepted = [Math]::Round($codeTotals.LinesAccepted * $w, 0)
    $estCodeAcceptances = [Math]::Round($codeTotals.CodeAcceptances * $w, 0)
    $estLinesSuggested = [Math]::Round($codeTotals.LinesSuggested * $w, 0)
    $estCodeSuggestions = [Math]::Round($codeTotals.CodeSuggestions * $w, 0)
    
    # Calculate acceptance rate
    $acceptanceRate = if ($estCodeSuggestions -gt 0) { 
        [Math]::Round(($estCodeAcceptances / $estCodeSuggestions) * 100, 1) 
    } else { 0 }
    
    $estimatedMetrics += [PSCustomObject]@{
        Username = $user.Username
        PlanType = $user.PlanType
        ActivityStatus = $user.ActivityStatus
        LastActivityAt = if ($user.LastActivityAt) { $user.LastActivityAt.ToString('yyyy-MM-dd HH:mm') } else { "" }
        LastActivityEditor = $user.LastActivityEditor
        EstimatedDaysActive = $user.EstimatedDaysActive
        ActivityWeight = [Math]::Round($user.NormalizedWeight * 100, 2)
        Est_TotalChats = $estChats
        Est_ChatCopyEvents = $estCopyEvents
        Est_ChatInsertEvents = $estInsertEvents
        Est_LinesAccepted = $estLinesAccepted
        Est_LinesSuggested = $estLinesSuggested
        Est_CodeAcceptances = $estCodeAcceptances
        Est_CodeSuggestions = $estCodeSuggestions
        Est_AcceptanceRatePct = $acceptanceRate
    }
}

# Sort by estimated chats descending (most active first)
$estimatedMetrics = $estimatedMetrics | Sort-Object Est_TotalChats -Descending

Write-Host " Done" -ForegroundColor Green
#endregion

#region Export to CSV
Write-Host "[5/5] Exporting to CSV..." -NoNewline

$estimatedMetrics | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

Write-Host " Done" -ForegroundColor Green
#endregion

#region Summary
Write-Host ""
Write-Host "============================================"
Write-Host "Estimation Complete" -ForegroundColor Cyan
Write-Host "============================================"
Write-Host ""
Write-Host "Output file: $OutputFile"
Write-Host ""
Write-Host "Top 10 Users by Estimated Chats:"
Write-Host "--------------------------------"
$estimatedMetrics | Select-Object -First 10 Username, ActivityStatus, Est_TotalChats, Est_LinesAccepted | Format-Table -AutoSize

Write-Host ""
Write-Host "Summary by Activity Status:"
$estimatedMetrics | Group-Object ActivityStatus | ForEach-Object {
    $sumChats = ($_.Group | Measure-Object -Property Est_TotalChats -Sum).Sum
    $sumLines = ($_.Group | Measure-Object -Property Est_LinesAccepted -Sum).Sum
    Write-Host "  $($_.Name): $($_.Count) users, Est. $sumChats chats, Est. $sumLines lines"
}

Write-Host ""
Write-Host "DISCLAIMER: These estimates are based on activity recency patterns."
Write-Host "            Actual per-user metrics are not available via GitHub API."
Write-Host "============================================"
#endregion
