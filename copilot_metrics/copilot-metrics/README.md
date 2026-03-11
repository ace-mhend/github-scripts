# Copilot Metrics - GitHub Actions

Automated GitHub Copilot metrics collection running via GitHub Actions on a self-hosted runner.

## Overview

This module fetches Copilot usage metrics from the GitHub API and generates Excel reports. It runs on a self-hosted runner (`lliss0768`) with scheduled cron triggers.

## Directory Structure

```
copilot-metrics/
├── .github/workflows/
│   ├── daily-metrics.yml      # Daily fetch + export (1 AM UTC)
│   ├── monthly-compile.yml    # Monthly aggregation (2 AM UTC on 1st)
│   └── manual-fetch.yml       # On-demand fetch with options
├── scripts/
│   ├── config.sh              # Configuration (env vars)
│   ├── fetch_combined_metrics.sh
│   ├── fetch_user_metrics.sh
│   ├── fetch_org_usage.sh
│   ├── fetch_enterprise_usage.sh
│   ├── fetch_all_orgs.sh
│   ├── fetch_detailed_metrics.sh
│   ├── fetch_usage_daterange.sh
│   ├── export_combined_metrics.py
│   ├── export_user_metrics.py
│   ├── compile_monthly.py
│   ├── summarize_usage.sh
│   └── export_to_csv.sh
├── config/
│   └── orgs_list.txt          # List of organizations
├── output/                     # Generated JSON/Excel files
└── requirements.txt            # Python dependencies
```

## Setup

### 1. Register Self-Hosted Runner

On `lliss0768`, register a GitHub Actions runner:

```bash
# Download runner
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure (get token from repo Settings → Actions → Runners → New self-hosted runner)
./config.sh --url https://github.com/ace-mhend/copilot --token YOUR_TOKEN --labels lliss0768

# Install as service
sudo ./svc.sh install
sudo ./svc.sh start
```

### 2. Install Dependencies on Runner

```bash
# Install required tools
sudo apt update
sudo apt install -y curl jq python3 python3-pip

# Install Python dependencies
pip3 install openpyxl
```

### 3. Configure Repository Secrets

In the `github-scripts` repo, add these secrets (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `COPILOT_METRICS_TOKEN` | GitHub PAT with `admin:enterprise` and `admin:org` scopes |

### 4. Verify Runner

Check that the runner appears in repo Settings → Actions → Runners with status "Idle".

## Workflows

### Daily Metrics

**Schedule**: 1 AM UTC daily  
**Trigger**: `daily-metrics.yml`

Fetches combined user seats and metrics, exports to Excel in monthly folder.

```yaml
# Manual trigger
gh workflow run daily-metrics.yml
```

### Monthly Compile

**Schedule**: 2 AM UTC on 1st of month  
**Trigger**: `monthly-compile.yml`

Compiles all daily reports from previous month into summary spreadsheet.

```yaml
# Manual trigger for specific month
gh workflow run monthly-compile.yml -f month=2026-02
```

### Manual Fetch

**Trigger**: `manual-fetch.yml`

On-demand fetch with configurable options:
- Fetch type: combined, user_metrics, org_usage, enterprise_usage, all_orgs, detailed_metrics, date_range
- Organization selection
- Date range for historical data
- Excel export option

```yaml
# Examples
gh workflow run manual-fetch.yml -f fetch_type=combined -f org=AceHdw
gh workflow run manual-fetch.yml -f fetch_type=date_range -f start_date=2026-01-01 -f end_date=2026-02-28
```

## Output Files

### JSON (Raw API responses)
- `combined_users_{org}_{timestamp}.json` - User seat assignments
- `combined_metrics_{org}_{timestamp}.json` - Detailed metrics

### Excel (Processed reports)
- `copilot_metrics_{date}_{timestamp}.xlsx` - Daily report with sheets:
  - Summary - Key metrics overview
  - ActiveUsers - Users sorted by username
  - ChatRequests - Chat requests by day
  - LinesOfCode - Code metrics by language

- `copilot_metrics_{YYYY-MM}_monthly_summary.xlsx` - Monthly aggregation with sheets:
  - MonthlySummary - Aggregated metrics
  - UserActivity - Per-user activity summary
  - DailyChatTotals - Chat requests by day
  - DailyCodeTotals - Code metrics by day

## Local Development

To run scripts locally:

```bash
# Set environment variables
export GITHUB_TOKEN="your_token"
export ORG="AceHdw"
export OUTPUT_DIR="./output"

# Make scripts executable
chmod +x scripts/*.sh

# Run fetch
./scripts/fetch_combined_metrics.sh

# Export to Excel
python3 scripts/export_combined_metrics.py --output-dir ./output
```

## Troubleshooting

### Runner not picking up jobs
```bash
# Check runner service status
sudo ./svc.sh status

# View runner logs
journalctl -u actions.runner.* -f
```

### API rate limiting
- Default: 5000 requests/hour for authenticated requests
- Scripts use pagination to minimize requests
- Check rate limit: `curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/rate_limit`

### Missing dependencies
```bash
# Verify curl and jq
which curl jq

# Verify Python and openpyxl
python3 -c "import openpyxl; print('OK')"
```
