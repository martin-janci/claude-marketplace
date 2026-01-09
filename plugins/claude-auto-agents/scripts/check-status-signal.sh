#!/usr/bin/env bash
# Check if agent output contains a valid STATUS signal
# Usage: check-status-signal.sh [output_file]
# Exits 0 if valid STATUS found, 1 otherwise

set -euo pipefail

OUTPUT_FILE="${1:-}"

# Read from stdin or file
if [[ -n "$OUTPUT_FILE" && -f "$OUTPUT_FILE" ]]; then
    CONTENT=$(cat "$OUTPUT_FILE")
elif [[ -p /dev/stdin ]]; then
    CONTENT=$(cat)
else
    echo "Usage: check-status-signal.sh [output_file]" >&2
    echo "       or pipe output to stdin" >&2
    exit 1
fi

# Check for STATUS signal pattern
if echo "$CONTENT" | grep -qE '^STATUS:\s*(COMPLETE|BLOCKED|WAITING|ERROR)'; then
    STATUS=$(echo "$CONTENT" | grep -oE '^STATUS:\s*(COMPLETE|BLOCKED|WAITING|ERROR)' | head -1 | sed 's/STATUS:\s*//')

    # Check for required SUMMARY field
    if echo "$CONTENT" | grep -qE '^SUMMARY:'; then
        SUMMARY=$(echo "$CONTENT" | grep -oE '^SUMMARY:.*' | head -1 | sed 's/SUMMARY:\s*//')

        echo "STATUS_VALID=true"
        echo "STATUS=$STATUS"
        echo "SUMMARY=$SUMMARY"

        # Check optional fields
        if echo "$CONTENT" | grep -qE '^FILES:'; then
            FILES=$(echo "$CONTENT" | grep -oE '^FILES:.*' | head -1 | sed 's/FILES:\s*//')
            echo "FILES=$FILES"
        fi

        if echo "$CONTENT" | grep -qE '^NEXT:'; then
            NEXT=$(echo "$CONTENT" | grep -oE '^NEXT:.*' | head -1 | sed 's/NEXT:\s*//')
            echo "NEXT=$NEXT"
        fi

        if echo "$CONTENT" | grep -qE '^BLOCKER:'; then
            BLOCKER=$(echo "$CONTENT" | grep -oE '^BLOCKER:.*' | head -1 | sed 's/BLOCKER:\s*//')
            echo "BLOCKER=$BLOCKER"
        fi

        exit 0
    else
        echo "STATUS_VALID=false"
        echo "ERROR=Missing SUMMARY field"
        exit 1
    fi
else
    echo "STATUS_VALID=false"
    echo "ERROR=No STATUS signal found"
    exit 1
fi
