#!/bin/bash
# ============================================
# Fetch Combined Copilot Metrics
# ============================================
# Fetches both user seats and detailed metrics
# Parameters:
#   $1 - Organization name (optional, uses config)
#   $2 - Days back to fetch (optional, default 1)
# ============================================

set -e

# Get script directory and load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Parse arguments
[[ -n "$1" ]] && ORG="$1"
DAYS_BACK="${2:-1}"

# Check for required tools
if ! command -v curl &> /dev/null; then
    echo "ERROR: curl is required but not found."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "WARNING: jq not found. JSON parsing will be limited."
fi

# Validate token
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "ERROR: GITHUB_TOKEN environment variable is not set."
    exit 1
fi

# Generate timestamp for output filename
TIMESTAMP=$(date +"%a%m%d_%Y%H%M%S")

USERS_FILE="$OUTPUT_DIR/combined_users_${ORG}_${TIMESTAMP}.json"
METRICS_FILE="$OUTPUT_DIR/combined_metrics_${ORG}_${TIMESTAMP}.json"

echo "============================================"
echo "Fetching Combined Copilot Metrics"
echo "============================================"
echo "Organization: $ORG"
echo "Days Back: $DAYS_BACK"
echo ""

# Fetch user seats
echo "[1/2] Fetching user seats..."
SEATS_ENDPOINT="$API_BASE_URL/orgs/$ORG/copilot/billing/seats"
curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$SEATS_ENDPOINT?per_page=100" > "$USERS_FILE"

if command -v jq &> /dev/null; then
    USER_COUNT=$(jq '.seats | length' "$USERS_FILE" 2>/dev/null || echo "0")
else
    USER_COUNT=$(grep -c '"login"' "$USERS_FILE" 2>/dev/null || echo "0")
fi
echo "  Retrieved $USER_COUNT users"

# Fetch detailed metrics
echo "[2/2] Fetching detailed metrics..."
METRICS_ENDPOINT="$API_BASE_URL/orgs/$ORG/copilot/metrics"
curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$METRICS_ENDPOINT?per_page=100" > "$METRICS_FILE"

if command -v jq &> /dev/null; then
    DAYS_COUNT=$(jq 'length' "$METRICS_FILE" 2>/dev/null || echo "0")
else
    DAYS_COUNT=$(grep -c '"date"' "$METRICS_FILE" 2>/dev/null || echo "0")
fi
echo "  Retrieved $DAYS_COUNT days of metrics"

echo ""
echo "============================================"
echo "Fetch Complete"
echo "============================================"
echo "Users file: $USERS_FILE"
echo "Metrics file: $METRICS_FILE"
echo ""
echo "Run export_combined_metrics.py to generate Excel report."
