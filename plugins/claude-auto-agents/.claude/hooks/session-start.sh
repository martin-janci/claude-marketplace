#!/bin/bash
# session-start.sh - Protocol injection and queue loading at session start
#
# This hook runs at the start of every Claude Code session.
# It injects the STATUS protocol and loads the current work queue.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Source library functions
source "$SCRIPT_DIR/lib/loop-control.sh" 2>/dev/null || true

# Read loop state
LOOP_STATE_FILE="$SCRIPT_DIR/lib/.loop-state"
LOOP_ACTIVE=false
LOOP_ITERATION=0
LOOP_PROMPT=""

if [[ -f "$LOOP_STATE_FILE" ]]; then
    source "$LOOP_STATE_FILE"
fi

# Output protocol injection
cat << 'PROTOCOL'
# Autonomous Agent Protocol

## STATUS Signal (Required)

At the END of every work unit, emit:

```
STATUS: COMPLETE | BLOCKED | WAITING | ERROR
SUMMARY: What was done (1-2 sentences)
FILES: Changed files (comma-separated)
NEXT: Suggested next action
```

## Loop Mode
PROTOCOL

if [[ "$LOOP_ACTIVE" == "true" ]]; then
    echo ""
    echo "**LOOP ACTIVE** - Iteration: $LOOP_ITERATION"
    echo "Original task: $LOOP_PROMPT"
    echo ""
    echo "Continue working on the task. Emit STATUS when done."
else
    echo ""
    echo "Loop is **inactive**. Use \`/loop \"task\"\` to start."
fi

# Show current work queue summary
QUEUE_FILE="$PROJECT_DIR/work/queue.md"
if [[ -f "$QUEUE_FILE" ]]; then
    echo ""
    echo "## Work Queue Summary"
    echo ""

    # Count items in each section
    IN_PROGRESS=$(grep -c "^\- \[ \]" "$QUEUE_FILE" 2>/dev/null | head -1 || echo "0")
    PENDING=$(grep -c "^- \[ \]" "$QUEUE_FILE" 2>/dev/null || echo "0")

    # Get first pending item
    NEXT_ITEM=$(grep -A1 "^## Pending" "$QUEUE_FILE" 2>/dev/null | grep "^\- \[ \]" | head -1 || echo "None")

    echo "- In Progress: ~$IN_PROGRESS items"
    echo "- Next up: $NEXT_ITEM"
fi

# Show current work context if exists
CURRENT_FILE="$PROJECT_DIR/work/current.md"
if [[ -f "$CURRENT_FILE" ]] && [[ -s "$CURRENT_FILE" ]]; then
    CURRENT_CONTENT=$(head -20 "$CURRENT_FILE")
    if [[ "$CURRENT_CONTENT" != *"No work in progress"* ]]; then
        echo ""
        echo "## Active Work Context"
        echo ""
        echo "$CURRENT_CONTENT"
    fi
fi
