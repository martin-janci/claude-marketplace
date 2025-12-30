#!/bin/bash
# on-stop.sh - Ralph-loop continuation logic
#
# This hook runs when Claude tries to exit.
# If loop is active and STATUS is COMPLETE, it continues to next item.
# If BLOCKED/ERROR, it pauses and logs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Source library functions
source "$SCRIPT_DIR/lib/loop-control.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/status-parser.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/queue-manager.sh" 2>/dev/null || true

# Read loop state
LOOP_STATE_FILE="$SCRIPT_DIR/lib/.loop-state"
LOOP_ACTIVE=false
LOOP_ITERATION=0
LOOP_MAX_ITERATIONS=50
LOOP_PROMPT=""

if [[ -f "$LOOP_STATE_FILE" ]]; then
    source "$LOOP_STATE_FILE"
fi

# If loop is not active, allow normal exit
if [[ "$LOOP_ACTIVE" != "true" ]]; then
    exit 0
fi

# Check iteration limit
if [[ $LOOP_ITERATION -ge $LOOP_MAX_ITERATIONS ]]; then
    echo "LOOP: Max iterations ($LOOP_MAX_ITERATIONS) reached. Stopping."
    update_loop_state "false" "0" ""
    exit 0
fi

# Get the last output from Claude (via environment or temp file)
# In practice, this would parse the conversation output
LAST_OUTPUT="${CLAUDE_LAST_OUTPUT:-}"

# Parse STATUS from output
STATUS=$(echo "$LAST_OUTPUT" | grep -E "^STATUS:" | head -1 | cut -d: -f2 | tr -d ' ' || echo "")
SUMMARY=$(echo "$LAST_OUTPUT" | grep -E "^SUMMARY:" | head -1 | cut -d: -f2- | sed 's/^ *//' || echo "")
FILES=$(echo "$LAST_OUTPUT" | grep -E "^FILES:" | head -1 | cut -d: -f2- | sed 's/^ *//' || echo "")
NEXT=$(echo "$LAST_OUTPUT" | grep -E "^NEXT:" | head -1 | cut -d: -f2- | sed 's/^ *//' || echo "")
BLOCKER=$(echo "$LAST_OUTPUT" | grep -E "^BLOCKER:" | head -1 | cut -d: -f2- | sed 's/^ *//' || echo "")

# Increment iteration
NEW_ITERATION=$((LOOP_ITERATION + 1))

case "$STATUS" in
    "COMPLETE")
        echo "LOOP: Iteration $NEW_ITERATION - Work completed."

        # Log to history
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "| $TIMESTAMP | - | $SUMMARY | - | $NEW_ITERATION |" >> "$PROJECT_DIR/work/history.md"

        # Update loop state
        update_loop_state "true" "$NEW_ITERATION" "$LOOP_PROMPT"

        # Continue - output prompt for next iteration
        echo ""
        echo "Continue with the next work item from queue."
        echo "Current iteration: $NEW_ITERATION / $LOOP_MAX_ITERATIONS"
        if [[ -n "$NEXT" ]]; then
            echo "Suggested next: $NEXT"
        fi

        # Block exit to continue loop (exit code 2 is intercepted)
        exit 2
        ;;

    "BLOCKED")
        echo "LOOP: Iteration $NEW_ITERATION - Blocked."
        echo "Reason: $BLOCKER"

        # Log blocker
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "| - | $BLOCKER | $TIMESTAMP | - |" >> "$PROJECT_DIR/work/blockers.md"

        # Pause loop
        update_loop_state "false" "$NEW_ITERATION" "$LOOP_PROMPT"
        echo "Loop paused. Use /loop to resume after resolving blocker."
        exit 0
        ;;

    "WAITING")
        echo "LOOP: Iteration $NEW_ITERATION - Waiting for external event."

        # Update state but don't increment iteration
        update_loop_state "true" "$LOOP_ITERATION" "$LOOP_PROMPT"

        echo "Will retry on next iteration."
        exit 2
        ;;

    "ERROR")
        echo "LOOP: Iteration $NEW_ITERATION - Error encountered."

        # Log error
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "| - | ERROR: $SUMMARY | $TIMESTAMP | - |" >> "$PROJECT_DIR/work/blockers.md"

        # Check for consecutive errors (would need state tracking)
        # For now, pause on error
        update_loop_state "false" "$NEW_ITERATION" "$LOOP_PROMPT"
        echo "Loop paused due to error. Review and use /loop to resume."
        exit 0
        ;;

    *)
        # No STATUS found - check if there's still work to do
        echo "LOOP: Iteration $NEW_ITERATION - No STATUS signal detected."
        echo "Reminder: Emit STATUS signal at end of work."

        # Continue anyway
        update_loop_state "true" "$NEW_ITERATION" "$LOOP_PROMPT"
        exit 2
        ;;
esac

# Helper function to update loop state
update_loop_state() {
    local active="$1"
    local iteration="$2"
    local prompt="$3"

    cat > "$LOOP_STATE_FILE" << EOF
LOOP_ACTIVE=$active
LOOP_ITERATION=$iteration
LOOP_MAX_ITERATIONS=$LOOP_MAX_ITERATIONS
LOOP_PROMPT="$prompt"
LOOP_STARTED="${LOOP_STARTED:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
EOF
}
