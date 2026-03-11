$ORG = "AceHdw"

Write-Host "Fetching all org members for $ORG..." -ForegroundColor Cyan

# 1) Get all org members
$allMembers = gh api graphql -f query='
query($org:String!, $cursor:String) {
  organization(login:$org) {
    membersWithRole(first:100, after:$cursor) {
      nodes { login }
      pageInfo { hasNextPage endCursor }
    }
  }
}' -f org="$ORG" --paginate --jq '.data.organization.membersWithRole.nodes[].login' | Sort-Object -Unique

Write-Host "Found $($allMembers.Count) org members" -ForegroundColor Green

# 2) Get all Copilot seat assignees in the org
Write-Host "Fetching Copilot seat assignments for $ORG..." -ForegroundColor Cyan

$copilotUsers = gh api -H "Accept: application/vnd.github+json" "/orgs/$ORG/copilot/billing/seats" --paginate --jq '.seats[].assignee.login' 2>$null | Sort-Object -Unique

if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Could not fetch Copilot seats. You may need org admin permissions or the endpoint may differ for your enterprise." -ForegroundColor Yellow
    $copilotUsers = @()
} else {
    Write-Host "Found $($copilotUsers.Count) users with Copilot seats" -ForegroundColor Green
}

# 3) Find members without Copilot seats (set difference)
$noCopilot = $allMembers | Where-Object { $_ -notin $copilotUsers }

Write-Host "Found $($noCopilot.Count) members WITHOUT Copilot access" -ForegroundColor Yellow

# 4) Write CSV
$csvPath = "no_copilot_access.csv"
$csvContent = @("login,has_copilot")
foreach ($user in $noCopilot) {
    $csvContent += "$user,false"
}
$csvContent | Out-File -FilePath $csvPath -Encoding UTF8

Write-Host "`nWrote: $csvPath" -ForegroundColor Green
Write-Host "Total rows (including header): $($csvContent.Count)" -ForegroundColor Green
