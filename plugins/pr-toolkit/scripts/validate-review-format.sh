#!/usr/bin/env bash
# Validate code review output format
# Checks for required sections: Review Summary, Verdict, and Issues/Suggestions
# Usage: validate-review-format.sh [output_file]
# Exits 0 if valid, 1 otherwise

set -euo pipefail

OUTPUT_FILE="${1:-}"

# Read from stdin or file
if [[ -n "$OUTPUT_FILE" && -f "$OUTPUT_FILE" ]]; then
    CONTENT=$(cat "$OUTPUT_FILE")
elif [[ -p /dev/stdin ]]; then
    CONTENT=$(cat)
else
    echo "Usage: validate-review-format.sh [output_file]" >&2
    echo "       or pipe output to stdin" >&2
    exit 1
fi

ERRORS=()
WARNINGS=()

# Check for Review Summary section
if ! echo "$CONTENT" | grep -qiE '##\s*Review\s*Summary|##\s*Summary'; then
    ERRORS+=("Missing Review Summary section")
fi

# Check for Verdict
if echo "$CONTENT" | grep -qiE '\*\*Verdict\*\*:\s*(APPROVED|CHANGES_REQUESTED|NEEDS_DISCUSSION)|Verdict:\s*(APPROVED|CHANGES_REQUESTED|NEEDS_DISCUSSION)'; then
    VERDICT=$(echo "$CONTENT" | grep -oiE '(APPROVED|CHANGES_REQUESTED|NEEDS_DISCUSSION)' | head -1 | tr '[:lower:]' '[:upper:]')
    echo "VERDICT=$VERDICT"
else
    ERRORS+=("Missing or invalid Verdict (expected APPROVED, CHANGES_REQUESTED, or NEEDS_DISCUSSION)")
fi

# Check for Issues section if not APPROVED
if [[ -v VERDICT ]] && [[ "$VERDICT" != "APPROVED" ]]; then
    if ! echo "$CONTENT" | grep -qiE '##\s*Issues|###\s*Critical|###\s*Major|###\s*Minor'; then
        WARNINGS+=("Verdict is $VERDICT but no Issues section found")
    fi
fi

# Check for Suggestions section (optional but recommended)
if ! echo "$CONTENT" | grep -qiE '##\s*Suggestions'; then
    WARNINGS+=("Missing Suggestions section (recommended)")
fi

# Check for STATUS signal (required for agent output)
if echo "$CONTENT" | grep -qE '^STATUS:\s*(COMPLETE|BLOCKED|WAITING|ERROR)'; then
    STATUS=$(echo "$CONTENT" | grep -oE '^STATUS:\s*(COMPLETE|BLOCKED|WAITING|ERROR)' | head -1 | sed 's/STATUS:\s*//')
    echo "STATUS=$STATUS"
else
    WARNINGS+=("Missing STATUS signal")
fi

# Output results
echo "REVIEW_VALID=$([[ ${#ERRORS[@]} -eq 0 ]] && echo true || echo false)"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "ERRORS:"
    for err in "${ERRORS[@]}"; do
        echo "  - $err"
    done
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "WARNINGS:"
    for warn in "${WARNINGS[@]}"; do
        echo "  - $warn"
    done
fi

# Exit with error if validation failed
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    exit 1
fi

exit 0
