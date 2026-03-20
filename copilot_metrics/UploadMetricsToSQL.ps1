<#
.SYNOPSIS
    Uploads Copilot metrics JSON data to SQL Server database.

.DESCRIPTION
    Reads combined_metrics_*.json and combined_users_*.json files from the output directory,
    flattens the nested JSON structures, and uploads to the DevOpsUtilities database.
    
    Creates the following tables if they don't exist:
    - CopilotDailyMetrics: Summary metrics per day
    - CopilotChatMetrics: Chat metrics per day/editor
    - CopilotCodeCompletions: Code completion metrics per day/editor/language
    - CopilotUserSeats: User seat and activity information

.PARAMETER OutputDir
    Path to the directory containing the JSON output files. Defaults to script directory\output.

.PARAMETER SqlInstance
    SQL Server instance. Defaults to OAKS0490.npcorp.npacehdw.com.

.PARAMETER Database
    Target database name. Defaults to DevOpsUtilities.

.PARAMETER Organization
    Organization name for tagging records. Defaults to AceHdw.

.EXAMPLE
    .\UploadMetricsToSQL.ps1

.EXAMPLE
    .\UploadMetricsToSQL.ps1 -OutputDir "C:\metrics\output" -Organization "MyOrg"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "$PSScriptRoot\output",

    [Parameter(Mandatory = $false)]
    [string]$SqlInstance = 'OAKS0490.npcorp.npacehdw.com',

    [Parameter(Mandatory = $false)]
    [string]$Database = 'DevOpsUtilities',

    [Parameter(Mandatory = $false)]
    [string]$Organization = 'AceHdw',

    [Parameter(Mandatory = $false)]
    [switch]$SkipUserSeats,

    [Parameter(Mandatory = $false)]
    [switch]$SkipMetrics
)

#region Module Install (If Needed)
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Write-Host "Installing NuGet provider..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Import-PackageProvider -Name NuGet -Force
    }
    Write-Host "Installing dbatools module..."
    Install-Module -Name dbatools -Force -Scope CurrentUser
}
Import-Module dbatools
#endregion

#region Helper Functions

function Get-LatestJsonFile {
    param (
        [string]$Directory,
        [string]$Pattern
    )
    Get-ChildItem -Path $Directory -Filter $Pattern -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function ConvertTo-DailyMetrics {
    param (
        [array]$MetricsJson,
        [string]$Organization
    )
    
    $dailyMetrics = @()
    foreach ($day in $MetricsJson) {
        # Calculate totals for IDE chat
        $ideChatTotal = 0
        $ideChatCopyEvents = 0
        $ideChatInsertionEvents = 0
        if ($day.copilot_ide_chat.editors) {
            foreach ($editor in $day.copilot_ide_chat.editors) {
                foreach ($model in $editor.models) {
                    $ideChatTotal += $model.total_chats
                    $ideChatCopyEvents += $model.total_chat_copy_events
                    $ideChatInsertionEvents += $model.total_chat_insertion_events
                }
            }
        }
        
        # Calculate totals for dotcom chat
        $dotcomChatTotal = 0
        if ($day.copilot_dotcom_chat.models) {
            foreach ($model in $day.copilot_dotcom_chat.models) {
                $dotcomChatTotal += $model.total_chats
            }
        }
        
        # Calculate totals for code completions
        $totalAcceptances = 0
        $totalSuggestions = 0
        $totalLinesAccepted = 0
        $totalLinesSuggested = 0
        if ($day.copilot_ide_code_completions.editors) {
            foreach ($editor in $day.copilot_ide_code_completions.editors) {
                foreach ($model in $editor.models) {
                    if ($model.languages) {
                        foreach ($lang in $model.languages) {
                            $totalAcceptances += $lang.total_code_acceptances
                            $totalSuggestions += $lang.total_code_suggestions
                            $totalLinesAccepted += $lang.total_code_lines_accepted
                            $totalLinesSuggested += $lang.total_code_lines_suggested
                        }
                    }
                }
            }
        }
        
        $acceptanceRate = if ($totalSuggestions -gt 0) { 
            [math]::Round(($totalAcceptances / $totalSuggestions) * 100, 2) 
        } else { 0 }
        
        $dailyMetrics += [PSCustomObject]@{
            Organization = $Organization
            MetricsDate = [datetime]$day.date
            TotalActiveUsers = $day.total_active_users
            TotalEngagedUsers = $day.total_engaged_users
            IdeChatTotal = $ideChatTotal
            IdeChatEngagedUsers = $day.copilot_ide_chat.total_engaged_users
            IdeChatCopyEvents = $ideChatCopyEvents
            IdeChatInsertionEvents = $ideChatInsertionEvents
            DotcomChatTotal = $dotcomChatTotal
            DotcomChatEngagedUsers = $day.copilot_dotcom_chat.total_engaged_users
            DotcomPREngagedUsers = $day.copilot_dotcom_pull_requests.total_engaged_users
            TotalCodeAcceptances = $totalAcceptances
            TotalCodeSuggestions = $totalSuggestions
            TotalLinesAccepted = $totalLinesAccepted
            TotalLinesSuggested = $totalLinesSuggested
            AcceptanceRatePercent = $acceptanceRate
            LoadedAt = Get-Date
        }
    }
    return $dailyMetrics
}

function ConvertTo-ChatMetrics {
    param (
        [array]$MetricsJson,
        [string]$Organization
    )
    
    $chatMetrics = @()
    foreach ($day in $MetricsJson) {
        # IDE Chat by editor
        if ($day.copilot_ide_chat.editors) {
            foreach ($editor in $day.copilot_ide_chat.editors) {
                foreach ($model in $editor.models) {
                    $chatMetrics += [PSCustomObject]@{
                        Organization = $Organization
                        MetricsDate = [datetime]$day.date
                        ChatSource = 'IDE'
                        EditorName = $editor.name
                        ModelName = $model.name
                        IsCustomModel = $model.is_custom_model
                        TotalChats = $model.total_chats
                        EngagedUsers = $model.total_engaged_users
                        CopyEvents = $model.total_chat_copy_events
                        InsertionEvents = $model.total_chat_insertion_events
                        LoadedAt = Get-Date
                    }
                }
            }
        }
        
        # Dotcom Chat
        if ($day.copilot_dotcom_chat.models) {
            foreach ($model in $day.copilot_dotcom_chat.models) {
                $chatMetrics += [PSCustomObject]@{
                    Organization = $Organization
                    MetricsDate = [datetime]$day.date
                    ChatSource = 'Dotcom'
                    EditorName = 'github.com'
                    ModelName = $model.name
                    IsCustomModel = $model.is_custom_model
                    TotalChats = $model.total_chats
                    EngagedUsers = $model.total_engaged_users
                    CopyEvents = $null
                    InsertionEvents = $null
                    LoadedAt = Get-Date
                }
            }
        }
    }
    return $chatMetrics
}

function ConvertTo-CodeCompletions {
    param (
        [array]$MetricsJson,
        [string]$Organization
    )
    
    $completions = @()
    foreach ($day in $MetricsJson) {
        if ($day.copilot_ide_code_completions.editors) {
            foreach ($editor in $day.copilot_ide_code_completions.editors) {
                foreach ($model in $editor.models) {
                    if ($model.languages) {
                        foreach ($lang in $model.languages) {
                            $acceptanceRate = if ($lang.total_code_suggestions -gt 0) {
                                [math]::Round(($lang.total_code_acceptances / $lang.total_code_suggestions) * 100, 2)
                            } else { 0 }
                            
                            $completions += [PSCustomObject]@{
                                Organization = $Organization
                                MetricsDate = [datetime]$day.date
                                EditorName = $editor.name
                                ModelName = $model.name
                                IsCustomModel = $model.is_custom_model
                                Language = $lang.name
                                EngagedUsers = $lang.total_engaged_users
                                CodeAcceptances = $lang.total_code_acceptances
                                CodeSuggestions = $lang.total_code_suggestions
                                LinesAccepted = $lang.total_code_lines_accepted
                                LinesSuggested = $lang.total_code_lines_suggested
                                AcceptanceRatePercent = $acceptanceRate
                                LoadedAt = Get-Date
                            }
                        }
                    }
                }
            }
        }
    }
    return $completions
}

function ConvertTo-UserSeats {
    param (
        [object]$UsersJson,
        [string]$Organization
    )
    
    $userSeats = @()
    foreach ($seat in $UsersJson.seats) {
        $userSeats += [PSCustomObject]@{
            Organization = $Organization
            Username = $seat.assignee.login
            UserId = $seat.assignee.id
            PlanType = $seat.plan_type
            CreatedAt = if ($seat.created_at) { [datetime]$seat.created_at } else { $null }
            LastActivityAt = if ($seat.last_activity_at) { [datetime]$seat.last_activity_at } else { $null }
            LastActivityEditor = $seat.last_activity_editor
            LastAuthenticatedAt = if ($seat.last_authenticated_at) { [datetime]$seat.last_authenticated_at } else { $null }
            PendingCancellationDate = if ($seat.pending_cancellation_date) { [datetime]$seat.pending_cancellation_date } else { $null }
            UpdatedAt = if ($seat.updated_at) { [datetime]$seat.updated_at } else { $null }
            TotalSeats = $UsersJson.total_seats
            LoadedAt = Get-Date
        }
    }
    return $userSeats
}

function Invoke-SqlTableCreate {
    param (
        [string]$SqlInstance,
        [string]$Database
    )
    
    $createTablesSql = @"
-- Daily summary metrics
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CopilotDailyMetrics')
CREATE TABLE CopilotDailyMetrics (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Organization NVARCHAR(100) NOT NULL,
    MetricsDate DATE NOT NULL,
    TotalActiveUsers INT,
    TotalEngagedUsers INT,
    IdeChatTotal INT,
    IdeChatEngagedUsers INT,
    IdeChatCopyEvents INT,
    IdeChatInsertionEvents INT,
    DotcomChatTotal INT,
    DotcomChatEngagedUsers INT,
    DotcomPREngagedUsers INT,
    TotalCodeAcceptances INT,
    TotalCodeSuggestions INT,
    TotalLinesAccepted INT,
    TotalLinesSuggested INT,
    AcceptanceRatePercent DECIMAL(5,2),
    LoadedAt DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT UQ_CopilotDailyMetrics UNIQUE (Organization, MetricsDate)
);

-- Chat metrics by editor/source
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CopilotChatMetrics')
CREATE TABLE CopilotChatMetrics (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Organization NVARCHAR(100) NOT NULL,
    MetricsDate DATE NOT NULL,
    ChatSource NVARCHAR(50) NOT NULL,
    EditorName NVARCHAR(100) NOT NULL,
    ModelName NVARCHAR(100),
    IsCustomModel BIT,
    TotalChats INT,
    EngagedUsers INT,
    CopyEvents INT,
    InsertionEvents INT,
    LoadedAt DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT UQ_CopilotChatMetrics UNIQUE (Organization, MetricsDate, ChatSource, EditorName, ModelName)
);

-- Code completions by language
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CopilotCodeCompletions')
CREATE TABLE CopilotCodeCompletions (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Organization NVARCHAR(100) NOT NULL,
    MetricsDate DATE NOT NULL,
    EditorName NVARCHAR(100) NOT NULL,
    ModelName NVARCHAR(100),
    IsCustomModel BIT,
    Language NVARCHAR(100) NOT NULL,
    EngagedUsers INT,
    CodeAcceptances INT,
    CodeSuggestions INT,
    LinesAccepted INT,
    LinesSuggested INT,
    AcceptanceRatePercent DECIMAL(5,2),
    LoadedAt DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT UQ_CopilotCodeCompletions UNIQUE (Organization, MetricsDate, EditorName, ModelName, Language)
);

-- User seat information
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CopilotUserSeats')
CREATE TABLE CopilotUserSeats (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Organization NVARCHAR(100) NOT NULL,
    Username NVARCHAR(100) NOT NULL,
    UserId BIGINT,
    PlanType NVARCHAR(50),
    CreatedAt DATETIME2,
    LastActivityAt DATETIME2,
    LastActivityEditor NVARCHAR(200),
    LastAuthenticatedAt DATETIME2,
    PendingCancellationDate DATE,
    UpdatedAt DATETIME2,
    TotalSeats INT,
    LoadedAt DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT UQ_CopilotUserSeats UNIQUE (Organization, Username, LoadedAt)
);

-- Create indexes for better query performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_CopilotDailyMetrics_Date')
    CREATE INDEX IX_CopilotDailyMetrics_Date ON CopilotDailyMetrics (MetricsDate);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_CopilotChatMetrics_Date')
    CREATE INDEX IX_CopilotChatMetrics_Date ON CopilotChatMetrics (MetricsDate);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_CopilotCodeCompletions_Date')
    CREATE INDEX IX_CopilotCodeCompletions_Date ON CopilotCodeCompletions (MetricsDate);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_CopilotUserSeats_Username')
    CREATE INDEX IX_CopilotUserSeats_Username ON CopilotUserSeats (Username);
"@
    
    Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query $createTablesSql
}

function Import-DataWithUpsert {
    param (
        [string]$SqlInstance,
        [string]$Database,
        [string]$TableName,
        [array]$Data,
        [string[]]$KeyColumns
    )
    
    if ($Data.Count -eq 0) {
        Write-Host "  No data to import for $TableName"
        return
    }
    
    # Create temp table and bulk import
    $tempTable = "#Temp_$TableName"
    
    # Get column names from data (excluding Id if present)
    $columns = $Data[0].PSObject.Properties.Name | Where-Object { $_ -ne 'Id' }
    
    # Build insert with ON DUPLICATE KEY handling via MERGE
    $columnList = $columns -join ', '
    $sourceColumns = $columns | ForEach-Object { "source.[$_]" }
    $sourceColumnList = $sourceColumns -join ', '
    $updateSet = ($columns | Where-Object { $_ -notin $KeyColumns } | ForEach-Object { "target.[$_] = source.[$_]" }) -join ', '
    $keyMatch = ($KeyColumns | ForEach-Object { "target.[$_] = source.[$_]" }) -join ' AND '
    
    $mergeSql = @"
MERGE INTO $TableName AS target
USING $tempTable AS source
ON $keyMatch
WHEN MATCHED THEN
    UPDATE SET $updateSet
WHEN NOT MATCHED THEN
    INSERT ($columnList)
    VALUES ($sourceColumnList);
"@
    
    try {
        # Bulk copy to temp table, then merge
        $Data | Write-DbaDbTableData -SqlInstance $SqlInstance -Database $Database -Table $tempTable -AutoCreateTable
        Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query $mergeSql
        Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query "DROP TABLE IF EXISTS $tempTable"
        Write-Host "  Imported $($Data.Count) records to $TableName"
    }
    catch {
        Write-Warning "  Error importing to ${TableName}: $_"
        # Fallback: try simple insert ignoring duplicates
        try {
            Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query "DROP TABLE IF EXISTS $tempTable"
            $Data | Write-DbaDbTableData -SqlInstance $SqlInstance -Database $Database -Table $TableName -AutoCreateTable
            Write-Host "  Imported $($Data.Count) records to $TableName (fallback method)"
        }
        catch {
            Write-Error "  Failed to import data to ${TableName}: $_"
        }
    }
}

#endregion

#region Main Execution

Write-Host "============================================"
Write-Host "Copilot Metrics SQL Upload"
Write-Host "============================================"
Write-Host "Output Directory: $OutputDir"
Write-Host "SQL Instance: $SqlInstance"
Write-Host "Database: $Database"
Write-Host "Organization: $Organization"
Write-Host ""

# Validate output directory
if (-not (Test-Path $OutputDir)) {
    Write-Error "Output directory not found: $OutputDir"
    exit 1
}

# Create tables if they don't exist
Write-Host "[1/5] Ensuring database tables exist..."
try {
    Invoke-SqlTableCreate -SqlInstance $SqlInstance -Database $Database
    Write-Host "  Tables verified/created successfully"
}
catch {
    Write-Error "Failed to create tables: $_"
    exit 1
}

if (-not $SkipMetrics) {
    # Find latest metrics file
    $metricsFile = Get-LatestJsonFile -Directory $OutputDir -Pattern "combined_metrics_*.json"
    
    if ($metricsFile) {
        Write-Host "[2/5] Processing metrics file: $(Split-Path $metricsFile -Leaf)"
        $metricsJson = Get-Content -Raw $metricsFile | ConvertFrom-Json
        
        Write-Host "[3/5] Uploading daily metrics..."
        $dailyMetrics = ConvertTo-DailyMetrics -MetricsJson $metricsJson -Organization $Organization
        Import-DataWithUpsert -SqlInstance $SqlInstance -Database $Database -TableName 'CopilotDailyMetrics' `
            -Data $dailyMetrics -KeyColumns @('Organization', 'MetricsDate')
        
        Write-Host "[4/5] Uploading chat metrics..."
        $chatMetrics = ConvertTo-ChatMetrics -MetricsJson $metricsJson -Organization $Organization
        Import-DataWithUpsert -SqlInstance $SqlInstance -Database $Database -TableName 'CopilotChatMetrics' `
            -Data $chatMetrics -KeyColumns @('Organization', 'MetricsDate', 'ChatSource', 'EditorName', 'ModelName')
        
        Write-Host "[5/5] Uploading code completion metrics..."
        $codeCompletions = ConvertTo-CodeCompletions -MetricsJson $metricsJson -Organization $Organization
        Import-DataWithUpsert -SqlInstance $SqlInstance -Database $Database -TableName 'CopilotCodeCompletions' `
            -Data $codeCompletions -KeyColumns @('Organization', 'MetricsDate', 'EditorName', 'ModelName', 'Language')
    }
    else {
        Write-Warning "No combined_metrics_*.json file found in $OutputDir"
    }
}
else {
    Write-Host "[2-5/5] Skipping metrics upload (SkipMetrics flag set)"
}

if (-not $SkipUserSeats) {
    # Find latest users file
    $usersFile = Get-LatestJsonFile -Directory $OutputDir -Pattern "combined_users_*.json"
    
    if ($usersFile) {
        Write-Host "[6/6] Processing user seats file: $(Split-Path $usersFile -Leaf)"
        $usersJson = Get-Content -Raw $usersFile | ConvertFrom-Json
        
        $userSeats = ConvertTo-UserSeats -UsersJson $usersJson -Organization $Organization
        # User seats use LoadedAt as part of key so each run creates new snapshot
        $userSeats | Write-DbaDbTableData -SqlInstance $SqlInstance -Database $Database -Table 'CopilotUserSeats' -AutoCreateTable
        Write-Host "  Imported $($userSeats.Count) user seat records"
    }
    else {
        Write-Warning "No combined_users_*.json file found in $OutputDir"
    }
}
else {
    Write-Host "[6/6] Skipping user seats upload (SkipUserSeats flag set)"
}

Write-Host ""
Write-Host "============================================"
Write-Host "Upload Complete"
Write-Host "============================================"

#endregion
