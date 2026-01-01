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

# Set component name for structured logging
COMPONENT="on-stop"

# Source library functions
# shellcheck source=lib/common.sh
if ! source "$SCRIPT_DIR/lib/common.sh" 2>/dev/null; then
    echo "ERROR: Failed to source common.sh" >&2
    exit 0  # Allow exit on source failure
fi
# shellcheck source=lib/loop-control.sh
source "$SCRIPT_DIR/lib/loop-control.sh" 2>/dev/null || true
# shellcheck source=lib/status-parser.sh
source "$SCRIPT_DIR/lib/status-parser.sh" 2>/dev/null || true
# shellcheck source=lib/queue-manager.sh
source "$SCRIPT_DIR/lib/queue-manager.sh" 2>/dev/null || true

# Start timing for this hook
start_timer

log_info "=== On-Stop Hook Triggered ==="
log_debug "Session ID: ${CLAUDE_SESSION_ID:-unknown}"

# Get directories
PROJECT_DIR="$(get_project_dir 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}")"
WORK_DIR="$PROJECT_DIR/work"

# Read loop state
read_loop_state 2>/dev/null || true

# If loop is not active, allow normal exit
if [[ "${LOOP_ACTIVE:-false}" != "true" ]]; then
    log_debug "Loop not active, allowing exit"
    log_operation "on-stop" "exit" "reason=loop_inactive"
    exit 0
fi

# Check iteration limit
if [[ ${LOOP_ITERATION:-0} -ge ${LOOP_MAX_ITERATIONS:-50} ]]; then
    echo "LOOP: Max iterations (${LOOP_MAX_ITERATIONS:-50}) reached. Stopping."
    log_iteration_end "MAX_ITERATIONS" "Reached iteration limit"
    stop_loop 2>/dev/null || true
    log_info "Loop stopped: max iterations reached"
    log_operation "on-stop" "exit" "reason=max_iterations"
    exit 0
fi

# === Read STATUS (file first, then env fallback) ===

STATUS_VALUE=""
STATUS_SUMMARY=""
STATUS_NEXT=""
STATUS_BLOCKER=""
STATUS_VALID="false"
STATUS_SOURCE="none"

log_debug "Checking STATUS sources..."

# Try to read from file first
STATUS_FILE="$WORK_DIR/.status"
if [[ -f "$STATUS_FILE" ]]; then
    log_debug "Reading STATUS from file: $STATUS_FILE"
    # shellcheck disable=SC2034  # Variables used below
    eval "$(read_status "$STATUS_FILE")"

    if [[ "$STATUS_VALID" == "true" ]]; then
        STATUS_SOURCE="file"
        # Clear the status file after reading
        clear_status "$STATUS_FILE" 2>/dev/null || true
        log_debug "STATUS from file: $STATUS_VALUE"
    fi
fi

# Fall back to environment variable if no valid file status
if [[ "$STATUS_VALID" != "true" ]] && [[ -n "${CLAUDE_LAST_OUTPUT:-}" ]]; then
    log_debug "Falling back to CLAUDE_LAST_OUTPUT"

    if has_status "$CLAUDE_LAST_OUTPUT" 2>/dev/null; then
        STATUS_VALUE=$(get_status_value "$CLAUDE_LAST_OUTPUT")
        STATUS_SUMMARY=$(echo "$CLAUDE_LAST_OUTPUT" | grep -E "^SUMMARY:" | head -1 | cut -d: -f2- | sed 's/^ *//')
        STATUS_NEXT=$(echo "$CLAUDE_LAST_OUTPUT" | grep -E "^NEXT:" | head -1 | cut -d: -f2- | sed 's/^ *//')
        STATUS_BLOCKER=$(echo "$CLAUDE_LAST_OUTPUT" | grep -E "^BLOCKER:" | head -1 | cut -d: -f2- | sed 's/^ *//')
        STATUS_VALID="true"
        STATUS_SOURCE="env"
        log_debug "STATUS from env: $STATUS_VALUE"
    fi
fi

# Log STATUS details
if [[ -n "$STATUS_VALUE" ]]; then
    log_info "STATUS: $STATUS_VALUE (source: $STATUS_SOURCE)"
    log_debug "SUMMARY: ${STATUS_SUMMARY:-none}"
    log_debug "FILES: ${STATUS_FILES:-none}"
    log_debug "BLOCKER: ${STATUS_BLOCKER:-none}"
else
    log_warn "No STATUS signal detected"
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
        log_info "Processing COMPLETE status"
        echo "LOOP: Iteration $NEW_ITERATION - Work completed."

        # Log iteration end with timing
        log_iteration_end "COMPLETE" "$STATUS_SUMMARY"

        # Reset consecutive errors and WAITING count on success
        reset_errors 2>/dev/null || true
        reset_waiting 2>/dev/null || true

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
            log_info "Loop stopped: queue empty"
            log_operation "on-stop" "exit" "reason=queue_empty"
            exit 0
        fi

        # Continue to next item
        echo ""
        echo "Continue with the next work item from queue."
        echo "Current iteration: $NEW_ITERATION / ${LOOP_MAX_ITERATIONS:-50}"
        if [[ -n "$STATUS_NEXT" ]]; then
            echo "Suggested next: $STATUS_NEXT"
        fi

        log_info "Iteration $NEW_ITERATION complete: $STATUS_SUMMARY"
        log_operation "on-stop" "continue" "status=COMPLETE"
        exit 2
        ;;

    "BLOCKED")
        log_info "Processing BLOCKED status: $STATUS_BLOCKER"
        echo "LOOP: Iteration $NEW_ITERATION - Blocked."
        echo "Reason: $STATUS_BLOCKER"

        # Log iteration end with timing
        log_iteration_end "BLOCKED" "$STATUS_BLOCKER"

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
        log_info "Loop paused: BLOCKED - $STATUS_BLOCKER"
        log_operation "on-stop" "exit" "reason=blocked"
        exit 0
        ;;

    "WAITING")
        log_info "Processing WAITING status"
        echo "LOOP: Iteration $NEW_ITERATION - Waiting for external event."

        # Increment WAITING counter - this will return 1 if threshold exceeded
        if ! increment_waiting 2>/dev/null; then
            log_error "WAITING threshold exceeded, pausing loop"
            log_iteration_end "WAITING_TIMEOUT" "Max retries exceeded (${WAITING_THRESHOLD:-10})"
            echo ""
            echo "LOOP: Too many consecutive WAITING statuses. Pausing."
            echo "The agent may be stuck. Check work/.debug.log for details."
            stop_loop 2>/dev/null || true
            log_operation "on-stop" "exit" "reason=waiting_threshold"
            exit 0
        fi

        WAIT_COUNT=$(get_waiting_count 2>/dev/null || echo "?")
        echo "Will retry on next iteration. (WAITING count: $WAIT_COUNT / ${WAITING_THRESHOLD:-10})"

        set_last_status "WAITING" 2>/dev/null || true

        log_info "Iteration $NEW_ITERATION waiting (count: $WAIT_COUNT)"
        log_operation "on-stop" "continue" "status=WAITING,count=$WAIT_COUNT"
        exit 2
        ;;

    "ERROR")
        log_error "Processing ERROR status: $STATUS_SUMMARY"
        echo "LOOP: Iteration $NEW_ITERATION - Error encountered."
        echo "Error: $STATUS_SUMMARY"

        # Log iteration end with timing
        log_iteration_end "ERROR" "$STATUS_SUMMARY"

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
            log_info "Loop paused: too many errors ($ERROR_COUNT)"
            log_operation "on-stop" "exit" "reason=error_threshold"
            exit 0
        fi

        echo ""
        echo "Retrying... (consecutive errors: $ERROR_COUNT / ${ERROR_THRESHOLD:-3})"
        log_info "Iteration $NEW_ITERATION error (count: $ERROR_COUNT): $STATUS_SUMMARY"
        log_operation "on-stop" "continue" "status=ERROR,count=$ERROR_COUNT"
        exit 2
        ;;

    *)
        # No STATUS signal detected
        log_warn "Unknown or missing STATUS: '$STATUS_VALUE'"
        echo "LOOP: Iteration $NEW_ITERATION - No STATUS signal detected."

        # Log iteration end with unknown status
        log_iteration_end "UNKNOWN" "No STATUS signal emitted"

        # Check if queue is empty - if so, we're done
        if is_queue_empty 2>/dev/null; then
            echo "LOOP: Queue is empty. Stopping loop."
            stop_loop 2>/dev/null || true
            log_info "Loop stopped: queue empty, no STATUS"
            log_operation "on-stop" "exit" "reason=queue_empty_no_status"
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
        log_info "Iteration $NEW_ITERATION: no STATUS, continuing"
        log_operation "on-stop" "continue" "status=NONE"
        exit 2
        ;;
esac
