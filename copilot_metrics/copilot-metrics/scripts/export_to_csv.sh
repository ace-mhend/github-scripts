#!/bin/bash
# ============================================
# Export Copilot Usage to CSV
# ============================================
# Converts JSON usage data to CSV format
# Usage: export_to_csv.sh [json_file] [output_csv]
# ============================================

set -e

JSON_FILE="$1"
CSV_FILE="$2"

if [[ -z "$JSON_FILE" ]]; then
    echo "Usage: $(basename "$0") [json_file] [output_csv]"
    echo ""
    echo "Converts Copilot usage JSON data to CSV format."
    exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
    echo "ERROR: File not found: $JSON_FILE"
    exit 1
fi

if [[ -z "$CSV_FILE" ]]; then
    CSV_FILE="${JSON_FILE%.json}.csv"
fi

echo "============================================"
echo "Exporting Usage Data to CSV"
echo "============================================"
echo "Input:  $JSON_FILE"
echo "Output: $CSV_FILE"
echo ""

# Check if jq is available for proper JSON parsing
if command -v jq &> /dev/null; then
    # Write CSV header
    echo "day,total_suggestions_count,total_acceptances_count,total_lines_suggested,total_lines_accepted,total_active_users,total_chat_acceptances,total_chat_turns,total_active_chat_users" > "$CSV_FILE"

    # Parse JSON and export to CSV
    jq -r '.[] | [
        .day // "",
        .total_suggestions_count // 0,
        .total_acceptances_count // 0,
        .total_lines_suggested // 0,
        .total_lines_accepted // 0,
        .total_active_users // 0,
        .total_chat_acceptances // 0,
        .total_chat_turns // 0,
        .total_active_chat_users // 0
    ] | @csv' "$JSON_FILE" >> "$CSV_FILE" 2>/dev/null || {
        echo "WARNING: JSON structure may not match expected format."
        echo "Attempting alternative parsing..."
        
        # Alternative: try parsing as single object or different structure
        jq -r 'if type == "array" then .[] else . end | [
            .day // .date // "",
            .total_suggestions_count // 0,
            .total_acceptances_count // 0,
            .total_lines_suggested // 0,
            .total_lines_accepted // 0,
            .total_active_users // 0,
            .total_chat_acceptances // 0,
            .total_chat_turns // 0,
            .total_active_chat_users // 0
        ] | @csv' "$JSON_FILE" >> "$CSV_FILE" 2>/dev/null || true
    }

    LINES=$(wc -l < "$CSV_FILE")
    echo "Exported $((LINES - 1)) records to CSV."
else
    echo "WARNING: jq not found. Using basic parsing (may be incomplete)."
    
    # Basic fallback without jq
    echo "day,total_suggestions_count,total_acceptances_count,total_lines_suggested,total_lines_accepted,total_active_users,total_chat_acceptances,total_chat_turns,total_active_chat_users" > "$CSV_FILE"
    
    # Very basic extraction - won't work for complex JSON
    grep -o '"day"[[:space:]]*:[[:space:]]*"[^"]*"' "$JSON_FILE" 2>/dev/null | \
        cut -d'"' -f4 | while read -r day; do
        echo "$day,,,,,,,," >> "$CSV_FILE"
    done
    
    echo "Basic export complete. Install jq for full parsing: apt install jq"
fi

echo ""
echo "============================================"
echo "Export Complete"
echo "============================================"
echo "Output: $CSV_FILE"
