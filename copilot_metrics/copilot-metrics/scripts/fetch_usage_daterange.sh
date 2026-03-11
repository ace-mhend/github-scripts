#!/bin/bash
# ============================================
# Fetch Copilot Usage with Custom Date Range
# ============================================
# Usage: fetch_usage_daterange.sh [enterprise|org] [name] [start_date] [end_date] [granularity]
# Example: fetch_usage_daterange.sh org my-org 2026-01-01 2026-01-25 day
# ============================================

set -e

# Get script directory and load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Parse command line arguments
SCOPE="$1"
NAME="$2"
START_DATE="$3"
END_DATE="$4"
GRANULARITY="${5:-day}"

# Validate arguments
if [[ -z "$SCOPE" ]]; then
    echo "Usage: $(basename "$0") [enterprise|org] [name] [start_date] [end_date] [granularity]"
    echo ""
    echo "Arguments:"
    echo "  scope       - \"enterprise\" or \"org\""
    echo "  name        - Enterprise slug or organization name"
    echo "  start_date  - Start date in ISO format (YYYY-MM-DD)"
    echo "  end_date    - End date in ISO format (YYYY-MM-DD)"
    echo "  granularity - \"hour\" or \"day\" (optional, defaults to \"day\")"
    echo ""
    echo "Example:"
    echo "  $(basename "$0") org my-organization 2026-01-01 2026-01-25 day"
    echo "  $(basename "$0") enterprise my-enterprise 2026-01-01 2026-01-25 hour"
    exit 1
fi

if [[ "$SCOPE" != "enterprise" && "$SCOPE" != "org" ]]; then
    echo "ERROR: Scope must be \"enterprise\" or \"org\""
    exit 1
fi

if [[ -z "$NAME" ]]; then
    echo "ERROR: Name (enterprise slug or org name) is required."
    exit 1
fi

if [[ -z "$START_DATE" ]]; then
    echo "ERROR: Start date is required."
    exit 1
fi

if [[ -z "$END_DATE" ]]; then
    echo "ERROR: End date is required."
    exit 1
fi

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

# Build API endpoint based on scope
if [[ "$SCOPE" == "enterprise" ]]; then
    ENDPOINT="$API_BASE_URL/enterprises/$NAME/copilot/usage"
else
    ENDPOINT="$API_BASE_URL/orgs/$NAME/copilot/usage"
fi

# Build query parameters
PARAMS="?since=$START_DATE&until=$END_DATE&granularity=$GRANULARITY&per_page=$PER_PAGE"

# Generate timestamp for output filename
TIMESTAMP=$(date +"%a%m%d_%Y%H%M%S")

TEMP_FILE="$OUTPUT_DIR/temp_response.json"
HEADERS_FILE="$OUTPUT_DIR/headers.txt"
OUTPUT_PREFIX="$OUTPUT_DIR/${SCOPE}_usage_${NAME}_${START_DATE}_to_${END_DATE}"

echo "============================================"
echo "Fetching Copilot Usage"
echo "============================================"
echo "Scope: $SCOPE"
echo "Name: $NAME"
echo "Date Range: $START_DATE to $END_DATE"
echo "Granularity: $GRANULARITY"
echo "Endpoint: ${ENDPOINT}${PARAMS}"
echo ""

# Initialize pagination
PAGE=1
HAS_MORE=true
TOTAL_RECORDS=0

while $HAS_MORE; do
    echo "Fetching page $PAGE..."
    
    # Build paginated URL
    PAGE_URL="${ENDPOINT}${PARAMS}&page=${PAGE}"
    
    # Make API request with headers saved
    HTTP_CODE=$(curl -s -D "$HEADERS_FILE" -w "%{http_code}" \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$PAGE_URL" -o "$TEMP_FILE")
    
    if [[ "$HTTP_CODE" != "200" ]]; then
        echo "ERROR: API request failed with HTTP code $HTTP_CODE"
        cat "$TEMP_FILE"
        rm -f "$TEMP_FILE" "$HEADERS_FILE"
        exit 1
    fi
    
    # Check for API errors
    if grep -q '"message"' "$TEMP_FILE" 2>/dev/null; then
        cat "$TEMP_FILE"
        echo ""
        echo "ERROR: API returned an error message."
        rm -f "$TEMP_FILE" "$HEADERS_FILE"
        exit 1
    fi
    
    # Count records in this page
    PAGE_RECORDS=$(grep -c '"day"' "$TEMP_FILE" 2>/dev/null || echo "0")
    TOTAL_RECORDS=$((TOTAL_RECORDS + PAGE_RECORDS))
    
    echo "  Retrieved approximately $PAGE_RECORDS records from page $PAGE"
    
    # Copy current page to individual file
    cp "$TEMP_FILE" "${OUTPUT_PREFIX}_page${PAGE}_${TIMESTAMP}.json"
    
    # Check for more pages via Link header
    if grep -qi 'rel="next"' "$HEADERS_FILE" 2>/dev/null; then
        PAGE=$((PAGE + 1))
    else
        HAS_MORE=false
    fi
done

# Clean up
rm -f "$TEMP_FILE" "$HEADERS_FILE"

echo ""
echo "============================================"
echo "Fetch Complete"
echo "============================================"
echo "Total records: $TOTAL_RECORDS"
echo "Output saved to: ${OUTPUT_PREFIX}_page*_${TIMESTAMP}.json"
