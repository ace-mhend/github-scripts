#!/bin/bash
# ============================================
# Summarize Copilot Usage Data
# ============================================
# Parses JSON output and displays summary stats
# Usage: summarize_usage.sh [json_file]
# ============================================

JSON_FILE="$1"

if [[ -z "$JSON_FILE" ]]; then
    echo "Usage: $(basename "$0") [json_file]"
    exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
    echo "ERROR: File not found: $JSON_FILE"
    exit 1
fi

echo ""
echo "============================================"
echo "Usage Summary for: $(basename "$JSON_FILE")"
echo "============================================"

# Count metrics using grep (jq would be better but not required)
SUGGESTIONS=$(grep -c '"total_suggestions_count"' "$JSON_FILE" 2>/dev/null || echo "0")
ACCEPTANCES=$(grep -c '"total_acceptances_count"' "$JSON_FILE" 2>/dev/null || echo "0")
ACTIVE_USERS=$(grep -c '"total_active_users"' "$JSON_FILE" 2>/dev/null || echo "0")
DAYS=$(grep -c '"day"' "$JSON_FILE" 2>/dev/null || echo "0")
BREAKDOWN_ENTRIES=$(grep -c '"breakdown"' "$JSON_FILE" 2>/dev/null || echo "0")

echo ""
echo "Metrics Overview:"
echo "  Days of data:        $DAYS"
echo "  Suggestion entries:  $SUGGESTIONS"
echo "  Acceptance entries:  $ACCEPTANCES"
echo "  Active user entries: $ACTIVE_USERS"
echo "  Breakdown sections:  $BREAKDOWN_ENTRIES"
echo ""

# Extract and display language breakdown if available
echo "Checking for language breakdown..."
if grep -q '"language"' "$JSON_FILE" 2>/dev/null; then
    echo ""
    echo "Languages detected in usage data:"
    grep -o '"language"[[:space:]]*:[[:space:]]*"[^"]*"' "$JSON_FILE" 2>/dev/null | \
        cut -d'"' -f4 | sort -u | while read -r lang; do
        echo "  - $lang"
    done
fi

# Extract and display editor breakdown if available
if grep -q '"editor"' "$JSON_FILE" 2>/dev/null; then
    echo ""
    echo "Editors detected in usage data:"
    grep -o '"editor"[[:space:]]*:[[:space:]]*"[^"]*"' "$JSON_FILE" 2>/dev/null | \
        cut -d'"' -f4 | sort -u | while read -r editor; do
        echo "  - $editor"
    done
fi

echo ""
echo "============================================"
echo "Full JSON output saved to: $JSON_FILE"
echo "============================================"
