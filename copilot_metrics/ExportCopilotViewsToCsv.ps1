[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$SqlInstance = 'OAKS0490.npcorp.npacehdw.com',

    [Parameter(Mandatory = $false)]
    [string]$Database = 'DevOpsUtilities',

    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = 'C:\Users\mhend\.vscode\copilot\copilot_metrics\output',

    [Parameter(Mandatory = $false)]
    [datetime]$StartDate = '2026-03-01',

    [Parameter(Mandatory = $false)]
    [datetime]$EndDate = (Get-Date)
)

#region Module Install (If Needed)
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    if (-not (Get-PackageProvider -Name NuGet)) {
        Write-Host "Installing NuGet provider..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Import-PackageProvider -Name NuGet -Force
    }
    Write-Host "Installing dbatools module..."
    Install-Module -Name dbatools -Force -Scope CurrentUser
}
#endregion

Import-Module dbatools

#region Create Output Folder
if (-not (Test-Path -Path $OutputFolder)) {
    Write-Host "Creating output folder: $OutputFolder"
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}
#endregion

#region Connect to SQL Server
$connectionString = "Server=$SqlInstance;Database=$Database;Integrated Security=True;TrustServerCertificate=True"
#endregion

#region Define Views to Export
$dailyViews = @(
    'CopilotDailyChat',
    'CopilotDailyCodeByLanguage'
)

$monthlyViews = @(
    'CopilotMonthlyChat',
    'CopilotMonthlyCodeByLanguage',
    'CopilotMonthlySummary'
)
#endregion

#region Export Views to CSV
$startDateStr = $StartDate.ToString('yyyy-MM-dd')
$endDateStr = $EndDate.ToString('yyyy-MM-dd')

Write-Host "Exporting views from $Database on $SqlInstance"
Write-Host "Date range: $startDateStr to $endDateStr"
Write-Host "Output folder: $OutputFolder"
Write-Host ""

# Export daily views (filter by ReportDate)
foreach ($view in $dailyViews) {
    Write-Host "Exporting $view..." -NoNewline
    
    $query = "SELECT * FROM [dbo].[$view] WHERE [ReportDate] >= '$startDateStr' AND [ReportDate] <= '$endDateStr'"
    
    try {
        $data = Invoke-DbaQuery -SqlInstance $connectionString -Query $query
        
        if ($data) {
            $outputPath = Join-Path -Path $OutputFolder -ChildPath "$view.csv"
            $data | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
            Write-Host " Done ($($data.Count) rows)" -ForegroundColor Green
        }
        else {
            Write-Host " No data returned" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Export monthly views (filter by Month)
$startMonthStr = $StartDate.ToString('yyyy-MM-01')
$endMonthStr = $EndDate.ToString('yyyy-MM-01')

foreach ($view in $monthlyViews) {
    Write-Host "Exporting $view..." -NoNewline
    
    $query = "SELECT * FROM [dbo].[$view] WHERE [Month] >= '$startMonthStr' AND [Month] <= '$endMonthStr'"
    
    try {
        $data = Invoke-DbaQuery -SqlInstance $connectionString -Query $query
        
        if ($data) {
            $outputPath = Join-Path -Path $OutputFolder -ChildPath "$view.csv"
            $data | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8
            Write-Host " Done ($($data.Count) rows)" -ForegroundColor Green
        }
        else {
            Write-Host " No data returned" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Export complete. Files saved to: $OutputFolder" -ForegroundColor Cyan
#endregion
