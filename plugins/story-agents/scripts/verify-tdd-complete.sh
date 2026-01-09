#!/usr/bin/env bash
# Verify TDD workflow completion for story-developer agent
# Checks that tests exist and STATUS signal is present
# Usage: verify-tdd-complete.sh [output_file]

set -euo pipefail

OUTPUT_FILE="${1:-}"
WARNINGS=()

# Read from stdin or file
if [[ -n "$OUTPUT_FILE" && -f "$OUTPUT_FILE" ]]; then
    CONTENT=$(cat "$OUTPUT_FILE")
elif [[ -p /dev/stdin ]]; then
    CONTENT=$(cat)
else
    # No input, check git status instead
    CONTENT=""
fi

# Check for STATUS signal
if [[ -n "$CONTENT" ]]; then
    if echo "$CONTENT" | grep -qE '^STATUS:\s*(COMPLETE|BLOCKED|WAITING|ERROR)'; then
        STATUS=$(echo "$CONTENT" | grep -oE '^STATUS:\s*(COMPLETE|BLOCKED|WAITING|ERROR)' | head -1 | sed 's/STATUS:\s*//')
        echo "STATUS=$STATUS"
    else
        WARNINGS+=("Missing STATUS signal in output")
    fi
fi

# Check if tests were added/modified (from git)
if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
    # Check staged and unstaged changes for test files
    TEST_FILES=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(test|spec)\.(ts|js|tsx|jsx|py|rs|go)$|_test\.(go|py)$|tests?/' || true)

    if [[ -n "$TEST_FILES" ]]; then
        echo "TDD_VERIFIED=true"
        echo "TEST_FILES_CHANGED:"
        echo "$TEST_FILES" | while read -r file; do
            echo "  - $file"
        done
    else
        WARNINGS+=("No test files appear to have been modified")
        echo "TDD_VERIFIED=false"
    fi
else
    echo "TDD_VERIFIED=unknown"
    WARNINGS+=("Not in a git repository, cannot verify test changes")
fi

# Output warnings
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "WARNINGS:"
    for warn in "${WARNINGS[@]}"; do
        echo "  - $warn"
    done
fi

# Always exit 0 - this is informational, not blocking
exit 0
