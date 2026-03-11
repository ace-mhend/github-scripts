# GitHub Copilot Metrics Batch Scripts

A collection of Windows batch scripts for fetching GitHub Copilot usage metrics via the GitHub REST API.

## Prerequisites

- **Windows OS** with Command Prompt or PowerShell
- **curl** - Usually pre-installed on Windows 10+
- **GitHub Personal Access Token** with appropriate permissions:
  - `admin:enterprise` scope for enterprise-level queries
  - `admin:org` scope for organization-level queries
  - Or `manage_billing:copilot` for some endpoints

## Quick Start

1. **Configure your settings**
   Edit `config.bat` and set:
   - `GITHUB_TOKEN` - Your GitHub Personal Access Token
   - `ENTERPRISE` - Your enterprise slug (for enterprise queries)
   - `ORG` - Your organization name (for org queries)

2. **Run a script**
   ```cmd
   # Fetch enterprise usage
   fetch_enterprise_usage.bat

   # Fetch single org usage
   fetch_org_usage.bat

   # Fetch with custom date range
   fetch_usage_daterange.bat org my-org 2026-01-01 2026-01-25 day
   ```

## Scripts Overview

### `config.bat`
Shared configuration file. Set your credentials and defaults here.

### `fetch_enterprise_usage.bat`
Fetches Copilot usage for an entire enterprise (all organizations).
- **API Endpoint**: `GET /enterprises/{enterprise}/copilot/usage`
- **Output**: JSON files in `output/` directory

### `fetch_org_usage.bat`
Fetches Copilot usage for a single organization.
- **API Endpoint**: `GET /orgs/{org}/copilot/usage`
- **Usage**: `fetch_org_usage.bat [org-name]`
- **Output**: JSON files in `output/` directory

### `fetch_usage_daterange.bat`
Fetches usage with a custom date range.
- **Usage**: `fetch_usage_daterange.bat [enterprise|org] [name] [start_date] [end_date] [granularity]`
- **Example**: `fetch_usage_daterange.bat org my-org 2026-01-01 2026-01-25 day`

### `fetch_all_orgs.bat`
Batch process multiple organizations listed in `orgs_list.txt`.
- Create `orgs_list.txt` with one org name per line
- Runs `fetch_org_usage.bat` for each organization

### `fetch_detailed_metrics.bat`
Fetches detailed Copilot metrics with breakdown by language, editor, etc.
- **API Endpoint**: `GET /enterprises/{enterprise}/copilot/metrics` or `GET /orgs/{org}/copilot/metrics`
- **Usage**: `fetch_detailed_metrics.bat [enterprise|org] [name]`

### `summarize_usage.bat`
Parses JSON output and displays a summary of the usage data.
- **Usage**: `summarize_usage.bat [json_file]`

### `export_to_csv.bat`
Converts JSON usage data to CSV format.
- **Usage**: `export_to_csv.bat [json_file] [output_csv]`

## API Parameters

The scripts support the following query parameters:

| Parameter | Description | Values |
|-----------|-------------|--------|
| `since` | Start date | ISO 8601 format (YYYY-MM-DD) |
| `until` | End date | ISO 8601 format (YYYY-MM-DD) |
| `granularity` | Time granularity | `hour` or `day` |
| `per_page` | Results per page | 1-100 (default: 100) |
| `page` | Page number | Integer |

## Output Data

The API returns usage data including:
- `day` - Date of the usage data
- `total_suggestions_count` - Total code suggestions made
- `total_acceptances_count` - Total suggestions accepted
- `total_lines_suggested` - Total lines of code suggested
- `total_lines_accepted` - Total lines of code accepted
- `total_active_users` - Number of active users
- `total_chat_acceptances` - Chat suggestions accepted
- `total_chat_turns` - Number of chat interactions
- `total_active_chat_users` - Active chat users
- `breakdown` - Detailed breakdown by language, editor, etc.

## Directory Structure

```
copilot_metrics/
├── config.bat              # Configuration file
├── fetch_enterprise_usage.bat
├── fetch_org_usage.bat
├── fetch_usage_daterange.bat
├── fetch_all_orgs.bat
├── fetch_detailed_metrics.bat
├── summarize_usage.bat
├── export_to_csv.bat
├── orgs_list.txt          # List of orgs for batch processing
├── README.md
└── output/                 # Generated output files
    ├── enterprise_usage_*.json
    ├── org_usage_*.json
    └── *.csv
```

## Troubleshooting

### "ERROR: API returned an error message"
- Check your `GITHUB_TOKEN` is valid and has correct permissions
- Verify the enterprise slug or org name is correct
- Ensure your token has access to Copilot data

### "ERROR: curl is required but not found"
- Install curl or ensure it's in your PATH
- Windows 10+ should have curl pre-installed

### Rate Limiting
- GitHub API has rate limits (5000 requests/hour for authenticated requests)
- The scripts include pagination support to handle large datasets
- Consider adding delays between requests for large batch operations

## API Documentation

- [GitHub Copilot Usage API](https://docs.github.com/en/rest/copilot/copilot-usage)
- [GitHub Copilot Metrics API](https://docs.github.com/en/rest/copilot/copilot-metrics)
- [GitHub REST API Authentication](https://docs.github.com/en/rest/authentication)

## License

These scripts are provided as-is for fetching GitHub Copilot metrics data.
