#!/bin/bash
# ============================================
# Fetch Copilot Usage for Single Organization
# ============================================
# GET /orgs/{org}/copilot/usage
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

# Build API endpoint
ENDPOINT="$API_BASE_URL/orgs/$ORG/copilot/usage"

# Build query parameters
PARAMS=""
[[ -n "$START_DATE" ]] && PARAMS="${PARAMS}${PARAMS:+&}since=$START_DATE"
[[ -n "$END_DATE" ]] && PARAMS="${PARAMS}${PARAMS:+&}until=$END_DATE"
[[ -n "$GRANULARITY" ]] && PARAMS="${PARAMS}${PARAMS:+&}granularity=$GRANULARITY"
[[ -n "$PER_PAGE" ]] && PARAMS="${PARAMS}${PARAMS:+&}per_page=$PER_PAGE"
[[ -n "$PARAMS" ]] && PARAMS="?$PARAMS"

# Generate timestamp for output filename
TIMESTAMP=$(date +"%a%m%d_%Y%H%M%S")

TEMP_FILE="$OUTPUT_DIR/temp_response.json"
HEADERS_FILE="$OUTPUT_DIR/headers.txt"

echo "============================================"
echo "Fetching Copilot Usage for Organization: $ORG"
echo "============================================"
echo "Endpoint: ${ENDPOINT}${PARAMS}"
echo ""

# Initialize pagination
PAGE=1
HAS_MORE=true
TOTAL_RECORDS=0

while $HAS_MORE; do
    echo "Fetching page $PAGE..."
    
    # Build paginated URL
    if [[ -z "$PARAMS" ]]; then
        PAGE_URL="${ENDPOINT}?page=${PAGE}&per_page=${PER_PAGE}"
    else
        PAGE_URL="${ENDPOINT}${PARAMS}&page=${PAGE}"
    fi
    
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
    cp "$TEMP_FILE" "$OUTPUT_DIR/org_usage_${ORG}_page${PAGE}_${TIMESTAMP}.json"
    
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
echo "Output saved to: $OUTPUT_DIR/org_usage_${ORG}_page*_${TIMESTAMP}.json"
