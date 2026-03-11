#!/bin/bash
# ============================================
# Fetch Copilot Usage for Multiple Orgs
# ============================================
# Iterates through a list of organizations
# ============================================

set -e

# Get script directory and load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
source "$SCRIPT_DIR/config.sh"

# Organizations list file
ORGS_FILE="$CONFIG_DIR/orgs_list.txt"

if [[ ! -f "$ORGS_FILE" ]]; then
    echo "ERROR: Organizations list file not found: $ORGS_FILE"
    echo ""
    echo "Please create $ORGS_FILE with one organization name per line."
    echo "Example:"
    echo "  org-name-1"
    echo "  org-name-2"
    echo "  org-name-3"
    exit 1
fi

echo "============================================"
echo "Fetching Copilot Usage for Multiple Organizations"
echo "============================================"
echo ""

ORG_COUNT=0
SUCCESS_COUNT=0
FAIL_COUNT=0

while IFS= read -r CURRENT_ORG || [[ -n "$CURRENT_ORG" ]]; do
    # Skip empty lines and comments
    [[ -z "$CURRENT_ORG" ]] && continue
    [[ "$CURRENT_ORG" =~ ^# ]] && continue
    
    # Trim whitespace
    CURRENT_ORG=$(echo "$CURRENT_ORG" | xargs)
    [[ -z "$CURRENT_ORG" ]] && continue
    
    ORG_COUNT=$((ORG_COUNT + 1))
    echo ""
    echo "[$ORG_COUNT] Processing organization: $CURRENT_ORG"
    echo "--------------------------------------------"
    
    if "$SCRIPT_DIR/fetch_org_usage.sh" "$CURRENT_ORG"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "WARNING: Failed to fetch data for $CURRENT_ORG"
    fi
done < "$ORGS_FILE"

echo ""
echo "============================================"
echo "Batch Processing Complete!"
echo "============================================"
echo "Total organizations processed: $ORG_COUNT"
echo "Successful: $SUCCESS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""
echo "Output files saved to: $OUTPUT_DIR"
echo "============================================"
