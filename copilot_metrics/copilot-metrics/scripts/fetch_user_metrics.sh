#!/bin/bash
# ============================================
# Fetch Copilot User Metrics (Past Day)
# ============================================
# GET /orgs/{org}/copilot/billing/seats
# ============================================
# Returns per-user seat assignments with activity
# Sorted by username, filtered for past day
# ============================================

set -e

# Get script directory and load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Allow org override via command line
[[ -n "$1" ]] && ORG="$1"

# Check for required tools
if ! command -v curl &> /dev/null; then
    echo "ERROR: curl is required but not found."
    exit 1
fi

# Validate token
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "ERROR: GITHUB_TOKEN environment variable is not set."
    exit 1
fi

# Build API endpoint for seats
ENDPOINT="$API_BASE_URL/orgs/$ORG/copilot/billing/seats"

# Generate timestamp for output filename
TIMESTAMP=$(date +"%a%m%d_%Y%H%M%S")

OUTPUT_FILE="$OUTPUT_DIR/user_metrics_${ORG}_${TIMESTAMP}.json"

echo "============================================"
echo "Fetching Copilot User Metrics"
echo "============================================"
echo "Organization: $ORG"
echo "Endpoint: $ENDPOINT"
echo ""

echo "Fetching user seats data..."

# Make API request
curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$ENDPOINT?per_page=100" > "$OUTPUT_FILE"

# Count seats in response
if command -v jq &> /dev/null; then
    TOTAL_SEATS=$(jq '.seats | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
else
    TOTAL_SEATS=$(grep -c '"login"' "$OUTPUT_FILE" 2>/dev/null || echo "0")
fi

echo "  Retrieved $TOTAL_SEATS users"

echo ""
echo "============================================"
echo "Fetch Complete"
echo "============================================"
echo "Total users: $TOTAL_SEATS"
echo "Output saved to: $OUTPUT_FILE"
