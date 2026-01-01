#!/bin/bash
# on-stop.sh - Autonomous loop continuation logic
#
# This hook runs when Claude tries to exit.
# It reads STATUS from file (or env fallback), handles the status,
# and decides whether to continue the loop or stop.
#
# Exit codes:
#   0 = Stop loop (allow exit)
#   2 = Continue loop (block exit, trigger next iteration)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" 2>/dev/null || true
# shellcheck source=lib/loop-control.sh
source "$SCRIPT_DIR/lib/loop-control.sh" 2>/dev/null || true
# shellcheck source=lib/status-parser.sh
source "$SCRIPT_DIR/lib/status-parser.sh" 2>/dev/null || true
# shellcheck source=lib/queue-manager.sh
source "$SCRIPT_DIR/lib/queue-manager.sh" 2>/dev/null || true

# Get directories
PROJECT_DIR="$(get_project_dir 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}")"
WORK_DIR="$PROJECT_DIR/work"

# Read loop state
read_loop_state 2>/dev/null || true

# If loop is not active, allow normal exit
if [[ "${LOOP_ACTIVE:-false}" != "true" ]]; then
    log_debug "Loop not active, allowing exit" 2>/dev/null || true
    exit 0
fi

# Check iteration limit
if [[ ${LOOP_ITERATION:-0} -ge ${LOOP_MAX_ITERATIONS:-50} ]]; then
    echo "LOOP: Max iterations (${LOOP_MAX_ITERATIONS:-50}) reached. Stopping."
    stop_loop 2>/dev/null || true
    log_info "Loop stopped: max iterations reached" 2>/dev/null || true
    exit 0
fi

# === Read STATUS (file first, then env fallback) ===

STATUS_VALUE=""
STATUS_SUMMARY=""
STATUS_NEXT=""
STATUS_BLOCKER=""
STATUS_VALID="false"

# Try to read from file first
STATUS_FILE="$WORK_DIR/.status"
if [[ -f "$STATUS_FILE" ]]; then
    log_debug "Reading STATUS from file: $STATUS_FILE" 2>/dev/null || true
    # shellcheck disable=SC2034  # Variables used below
    eval "$(read_status "$STATUS_FILE")"

    if [[ "$STATUS_VALID" == "true" ]]; then
        # Clear the status file after reading
        clear_status "$STATUS_FILE" 2>/dev/null || true
        log_debug "STATUS from file: $STATUS_VALUE" 2>/dev/null || true
    fi
fi

# Fall back to environment variable if no valid file status
if [[ "$STATUS_VALID" != "true" ]] && [[ -n "${CLAUDE_LAST_OUTPUT:-}" ]]; then
    log_debug "Falling back to CLAUDE_LAST_OUTPUT" 2>/dev/null || true

    if has_status "$CLAUDE_LAST_OUTPUT" 2>/dev/null; then
        STATUS_VALUE=$(get_status_value "$CLAUDE_LAST_OUTPUT")
        STATUS_SUMMARY=$(echo "$CLAUDE_LAST_OUTPUT" | grep -E "^SUMMARY:" | head -1 | cut -d: -f2- | sed 's/^ *//')
        STATUS_NEXT=$(echo "$CLAUDE_LAST_OUTPUT" | grep -E "^NEXT:" | head -1 | cut -d: -f2- | sed 's/^ *//')
        STATUS_BLOCKER=$(echo "$CLAUDE_LAST_OUTPUT" | grep -E "^BLOCKER:" | head -1 | cut -d: -f2- | sed 's/^ *//')
        STATUS_VALID="true"
        log_debug "STATUS from env: $STATUS_VALUE" 2>/dev/null || true
    fi
fi

# Get current item from loop state
CURRENT_ITEM="${CURRENT_ITEM:-}"

# Increment iteration for this cycle
NEW_ITERATION=$((LOOP_ITERATION + 1))
increment_iteration 2>/dev/null || true

# Get timestamp for logging
TIMESTAMP=$(get_timestamp 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

# === Handle each STATUS ===

case "$STATUS_VALUE" in
    "COMPLETE")
        echo "LOOP: Iteration $NEW_ITERATION - Work completed."

        # Reset consecutive errors on success
        reset_errors 2>/dev/null || true

        # Complete the current item if we know what it is
        if [[ -n "$CURRENT_ITEM" ]]; then
            complete_item "$CURRENT_ITEM" "$STATUS_SUMMARY" "" "$NEW_ITERATION" 2>/dev/null || true
            clear_current_item 2>/dev/null || true
        fi

        # Log to history
        echo "| $TIMESTAMP | ${CURRENT_ITEM:-work} | $STATUS_SUMMARY | - | $NEW_ITERATION |" >> "$WORK_DIR/history.md" 2>/dev/null || true

        # Update last status
        set_last_status "COMPLETE" 2>/dev/null || true

        # Check if queue is empty
        if is_queue_empty 2>/dev/null; then
            echo "LOOP: Queue is empty. All work complete!"
            stop_loop 2>/dev/null || true
            log_info "Loop stopped: queue empty" 2>/dev/null || true
            exit 0
        fi

        # Continue to next item
        echo ""
        echo "Continue with the next work item from queue."
        echo "Current iteration: $NEW_ITERATION / ${LOOP_MAX_ITERATIONS:-50}"
        if [[ -n "$STATUS_NEXT" ]]; then
            echo "Suggested next: $STATUS_NEXT"
        fi

        log_info "Iteration $NEW_ITERATION complete: $STATUS_SUMMARY" 2>/dev/null || true
        exit 2
        ;;

    "BLOCKED")
        echo "LOOP: Iteration $NEW_ITERATION - Blocked."
        echo "Reason: $STATUS_BLOCKER"

        # Block the current item if we know what it is
        if [[ -n "$CURRENT_ITEM" ]]; then
            block_item "$CURRENT_ITEM" "$STATUS_BLOCKER" 2>/dev/null || true
            clear_current_item 2>/dev/null || true
        fi

        # Log blocker
        echo "| ${CURRENT_ITEM:-work} | $STATUS_BLOCKER | $TIMESTAMP | - |" >> "$WORK_DIR/blockers.md" 2>/dev/null || true

        # Update status and pause loop
        set_last_status "BLOCKED" 2>/dev/null || true
        stop_loop 2>/dev/null || true

        echo ""
        echo "Loop paused. Use /loop to resume after resolving blocker."
        log_info "Loop paused: BLOCKED - $STATUS_BLOCKER" 2>/dev/null || true
        exit 0
        ;;

    "WAITING")
        echo "LOOP: Iteration $NEW_ITERATION - Waiting for external event."
        echo "Will retry on next iteration."

        # Don't increment iteration for WAITING (already done above, but we note it)
        set_last_status "WAITING" 2>/dev/null || true

        log_info "Iteration $NEW_ITERATION waiting" 2>/dev/null || true
        exit 2
        ;;

    "ERROR")
        echo "LOOP: Iteration $NEW_ITERATION - Error encountered."
        echo "Error: $STATUS_SUMMARY"

        # Increment consecutive errors
        ERROR_COUNT=$(increment_errors 2>/dev/null || echo "1")

        # Log error
        echo "| ${CURRENT_ITEM:-work} | ERROR: $STATUS_SUMMARY | $TIMESTAMP | - |" >> "$WORK_DIR/blockers.md" 2>/dev/null || true

        # Update last status
        set_last_status "ERROR" 2>/dev/null || true

        # Check if we should pause due to too many errors
        if should_pause 2>/dev/null; then
            echo ""
            echo "LOOP: Too many consecutive errors ($ERROR_COUNT >= ${ERROR_THRESHOLD:-3}). Pausing."
            stop_loop 2>/dev/null || true
            log_info "Loop paused: too many errors ($ERROR_COUNT)" 2>/dev/null || true
            exit 0
        fi

        echo ""
        echo "Retrying... (consecutive errors: $ERROR_COUNT / ${ERROR_THRESHOLD:-3})"
        log_info "Iteration $NEW_ITERATION error (count: $ERROR_COUNT): $STATUS_SUMMARY" 2>/dev/null || true
        exit 2
        ;;

    *)
        # No STATUS signal detected
        echo "LOOP: Iteration $NEW_ITERATION - No STATUS signal detected."

        # Check if queue is empty - if so, we're done
        if is_queue_empty 2>/dev/null; then
            echo "LOOP: Queue is empty. Stopping loop."
            stop_loop 2>/dev/null || true
            log_info "Loop stopped: queue empty, no STATUS" 2>/dev/null || true
            exit 0
        fi

        # Queue has items, continue with a reminder
        echo ""
        echo "**Reminder:** Emit STATUS signal at end of work."
        echo ""
        echo "Valid values: COMPLETE | BLOCKED | WAITING | ERROR"
        echo ""
        echo "Continuing to next iteration..."

        set_last_status "" 2>/dev/null || true
        log_info "Iteration $NEW_ITERATION: no STATUS, continuing" 2>/dev/null || true
        exit 2
        ;;
esac
