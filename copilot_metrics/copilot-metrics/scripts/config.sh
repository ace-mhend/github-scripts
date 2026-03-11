#!/bin/bash
# ============================================
# GitHub Copilot Metrics - Configuration File
# ============================================
# This file is sourced by all fetch scripts.
# Token is expected from environment variable (set by GitHub Actions or .env file)
# ============================================

# Script directory (for relative paths)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# GitHub Token (from environment - set by GitHub Actions secrets)
# DO NOT hardcode tokens here!
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "ERROR: GITHUB_TOKEN environment variable is not set."
    echo "Set it via GitHub Actions secrets or export GITHUB_TOKEN=your_token"
    exit 1
fi

# Enterprise slug (for enterprise-level queries)
export ENTERPRISE="${ENTERPRISE:-ace-hardware}"

# Organization name (for org-level queries)
export ORG="${ORG:-AceHdw}"

# API Base URL (GitHub.com or GitHub Enterprise Server)
export API_BASE_URL="${API_BASE_URL:-https://api.github.com}"

# Default date range (ISO 8601 format: YYYY-MM-DD)
# Leave empty to use API defaults
export START_DATE="${START_DATE:-}"
export END_DATE="${END_DATE:-}"

# Granularity: hour or day
export GRANULARITY="${GRANULARITY:-day}"

# Pagination settings
export PER_PAGE="${PER_PAGE:-100}"

# Output directory for results
export OUTPUT_DIR="${OUTPUT_DIR:-$BASE_DIR/output}"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Configuration loaded successfully."
echo "  Organization: $ORG"
echo "  Enterprise: $ENTERPRISE"
echo "  Output directory: $OUTPUT_DIR"
