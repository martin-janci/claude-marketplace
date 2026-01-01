#!/bin/bash
# loop-control.sh - Loop iteration tracking and control
#
# Manages the autonomous loop state: active/inactive, iteration count, limits,
# error tracking, and current item tracking.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh" 2>/dev/null || true

# State file location (in work/ for persistence across context resets)
LOOP_STATE_FILE="$(get_work_dir 2>/dev/null || echo "$SCRIPT_DIR")/.loop-state"

# Default values
DEFAULT_MAX_ITERATIONS=50
DEFAULT_ERROR_THRESHOLD=3

# Additional defaults for hang detection
DEFAULT_WAITING_THRESHOLD=10

# Initialize loop state file if missing
init_loop_state() {
    if [[ ! -f "$LOOP_STATE_FILE" ]]; then
        cat > "$LOOP_STATE_FILE" << EOF
LOOP_ACTIVE=false
LOOP_ITERATION=0
LOOP_MAX_ITERATIONS=$DEFAULT_MAX_ITERATIONS
LOOP_PROMPT=""
LOOP_STARTED=""
CONSECUTIVE_ERRORS=0
ERROR_THRESHOLD=$DEFAULT_ERROR_THRESHOLD
CURRENT_ITEM=""
LAST_STATUS=""
LAST_UPDATE=""
WAITING_COUNT=0
WAITING_THRESHOLD=$DEFAULT_WAITING_THRESHOLD
ITERATION_START_MS=0
TOTAL_ELAPSED_MS=0
EOF
    fi
}

# Read current loop state
read_loop_state() {
    init_loop_state
    # shellcheck source=/dev/null
    source "$LOOP_STATE_FILE"
}

# Update loop state (full update)
# Note: This preserves WAITING_COUNT, WAITING_THRESHOLD, ITERATION_START_MS, TOTAL_ELAPSED_MS
update_loop_state() {
    local active="${1:-false}"
    local iteration="${2:-0}"
    local prompt="${3:-}"
    local max_iterations="${4:-$DEFAULT_MAX_ITERATIONS}"
    local started="${5:-$(get_timestamp 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")}"
    local consecutive_errors="${6:-0}"
    local error_threshold="${7:-$DEFAULT_ERROR_THRESHOLD}"
    local current_item="${8:-}"
    local last_status="${9:-}"

    # Preserve timing/waiting fields if they exist
    local waiting_count="${WAITING_COUNT:-0}"
    local waiting_threshold="${WAITING_THRESHOLD:-$DEFAULT_WAITING_THRESHOLD}"
    local iteration_start_ms="${ITERATION_START_MS:-0}"
    local total_elapsed_ms="${TOTAL_ELAPSED_MS:-0}"

    cat > "$LOOP_STATE_FILE" << EOF
LOOP_ACTIVE=$active
LOOP_ITERATION=$iteration
LOOP_MAX_ITERATIONS=$max_iterations
LOOP_PROMPT="$prompt"
LOOP_STARTED="$started"
CONSECUTIVE_ERRORS=$consecutive_errors
ERROR_THRESHOLD=$error_threshold
CURRENT_ITEM="$current_item"
LAST_STATUS="$last_status"
LAST_UPDATE="$(get_timestamp 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"
WAITING_COUNT=$waiting_count
WAITING_THRESHOLD=$waiting_threshold
ITERATION_START_MS=$iteration_start_ms
TOTAL_ELAPSED_MS=$total_elapsed_ms
EOF
}

# Update a single field in state
update_state_field() {
    local field="$1"
    local value="$2"

    read_loop_state

    # Ensure defaults if not set from state file
    ERROR_THRESHOLD="${ERROR_THRESHOLD:-$DEFAULT_ERROR_THRESHOLD}"
    WAITING_THRESHOLD="${WAITING_THRESHOLD:-$DEFAULT_WAITING_THRESHOLD}"

    case "$field" in
        LOOP_ACTIVE) LOOP_ACTIVE="$value" ;;
        LOOP_ITERATION) LOOP_ITERATION="$value" ;;
        CONSECUTIVE_ERRORS) CONSECUTIVE_ERRORS="$value" ;;
        CURRENT_ITEM) CURRENT_ITEM="$value" ;;
        LAST_STATUS) LAST_STATUS="$value" ;;
        WAITING_COUNT) WAITING_COUNT="$value" ;;
        WAITING_THRESHOLD) WAITING_THRESHOLD="$value" ;;
        ITERATION_START_MS) ITERATION_START_MS="$value" ;;
        TOTAL_ELAPSED_MS) TOTAL_ELAPSED_MS="$value" ;;
        *) return 1 ;;
    esac

    update_loop_state "$LOOP_ACTIVE" "$LOOP_ITERATION" "$LOOP_PROMPT" \
        "$LOOP_MAX_ITERATIONS" "$LOOP_STARTED" "$CONSECUTIVE_ERRORS" \
        "$ERROR_THRESHOLD" "$CURRENT_ITEM" "$LAST_STATUS"
}

# Start a new loop
start_loop() {
    local prompt="$1"
    local max_iterations="${2:-$DEFAULT_MAX_ITERATIONS}"

    update_loop_state "true" "0" "$prompt" "$max_iterations" \
        "$(get_timestamp 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        "0" "$DEFAULT_ERROR_THRESHOLD" "" ""

    log_info "Loop started: $prompt (max: $max_iterations)" 2>/dev/null || true
    echo "Loop started with prompt: $prompt"
    echo "Max iterations: $max_iterations"
}

# Stop the loop
stop_loop() {
    read_loop_state
    local final_iteration="$LOOP_ITERATION"

    update_loop_state "false" "0" "" "$LOOP_MAX_ITERATIONS" "" \
        "0" "$ERROR_THRESHOLD" "" ""

    log_info "Loop stopped after $final_iteration iterations" 2>/dev/null || true
    echo "Loop stopped after $final_iteration iterations."
}

# Check if loop is active
is_loop_active() {
    read_loop_state
    [[ "$LOOP_ACTIVE" == "true" ]]
}

# Get current iteration
get_iteration() {
    read_loop_state
    echo "$LOOP_ITERATION"
}

# Increment iteration
increment_iteration() {
    read_loop_state
    local new_iteration=$((LOOP_ITERATION + 1))
    update_state_field "LOOP_ITERATION" "$new_iteration"
    echo "$new_iteration"
}

# Check if at iteration limit
at_limit() {
    read_loop_state
    [[ $LOOP_ITERATION -ge $LOOP_MAX_ITERATIONS ]]
}

# === Error Tracking ===

# Increment consecutive error count, return new count
increment_errors() {
    read_loop_state
    local new_count=$((CONSECUTIVE_ERRORS + 1))
    update_state_field "CONSECUTIVE_ERRORS" "$new_count"
    echo "$new_count"
}

# Reset consecutive error count to 0
reset_errors() {
    update_state_field "CONSECUTIVE_ERRORS" "0"
}

# Check if should pause due to too many consecutive errors
should_pause() {
    read_loop_state
    [[ $CONSECUTIVE_ERRORS -ge $ERROR_THRESHOLD ]]
}

# Get current error count
get_error_count() {
    read_loop_state
    echo "$CONSECUTIVE_ERRORS"
}

# === Current Item Tracking ===

# Set the current item being worked on
set_current_item() {
    local item_id="$1"
    update_state_field "CURRENT_ITEM" "$item_id"
    log_debug "Current item set: $item_id" 2>/dev/null || true
}

# Get the current item
get_current_item() {
    read_loop_state
    echo "$CURRENT_ITEM"
}

# Clear the current item
clear_current_item() {
    update_state_field "CURRENT_ITEM" ""
}

# === Status Tracking ===

# Set the last status
set_last_status() {
    local status="$1"
    update_state_field "LAST_STATUS" "$status"
}

# Get the last status
get_last_status() {
    read_loop_state
    echo "$LAST_STATUS"
}

# === WAITING Counter (for hang detection) ===

# Increment WAITING count, return new count
# Returns 1 (failure) if threshold reached
increment_waiting() {
    read_loop_state
    local new_count=$((${WAITING_COUNT:-0} + 1))
    update_state_field "WAITING_COUNT" "$new_count"

    local threshold="${WAITING_THRESHOLD:-$DEFAULT_WAITING_THRESHOLD}"
    if [[ $new_count -ge $threshold ]]; then
        log_warn "WAITING threshold reached ($new_count attempts)" 2>/dev/null || true
        echo "$new_count"
        return 1  # Signal to pause
    fi

    echo "$new_count"
    return 0
}

# Reset WAITING count to 0
reset_waiting() {
    update_state_field "WAITING_COUNT" "0"
}

# Get current WAITING count
get_waiting_count() {
    read_loop_state
    echo "${WAITING_COUNT:-0}"
}

# Check if WAITING threshold exceeded
waiting_threshold_exceeded() {
    read_loop_state
    local threshold="${WAITING_THRESHOLD:-$DEFAULT_WAITING_THRESHOLD}"
    [[ ${WAITING_COUNT:-0} -ge $threshold ]]
}

# === Iteration History Logging ===

# Get current time in milliseconds (portable)
get_time_ms() {
    # macOS date doesn't support %N, so we check for it properly
    local test_output
    test_output=$(date +%s%3N 2>/dev/null)
    # If the output contains 'N', the format wasn't supported
    if [[ "$test_output" == *"N"* ]] || [[ -z "$test_output" ]]; then
        echo "$(($(date +%s) * 1000))"
    else
        echo "$test_output"
    fi
}

# Log iteration start to history file
log_iteration_start() {
    read_loop_state
    local work_dir
    work_dir="$(get_work_dir 2>/dev/null || echo ".")"

    # Record start time
    ITERATION_START_MS=$(get_time_ms)
    update_state_field "ITERATION_START_MS" "$ITERATION_START_MS"

    # Escape summary for JSON
    local escaped_item
    escaped_item=$(printf '%s' "${CURRENT_ITEM:-}" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')

    # Write start entry to iteration history
    local history_entry
    history_entry="{\"iteration\":${LOOP_ITERATION:-0},\"item\":\"$escaped_item\",\"started\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"status\":\"started\"}"

    echo "$history_entry" >> "$work_dir/.iteration-history.jsonl"
    log_debug "Iteration $LOOP_ITERATION started: $CURRENT_ITEM" 2>/dev/null || true
}

# Log iteration end to history file
log_iteration_end() {
    local status="$1"
    local summary="${2:-}"
    read_loop_state
    local work_dir
    work_dir="$(get_work_dir 2>/dev/null || echo ".")"

    local now_ms
    now_ms=$(get_time_ms)
    local elapsed_ms=$((now_ms - ${ITERATION_START_MS:-now_ms}))

    # Update total elapsed time
    local new_total=$((${TOTAL_ELAPSED_MS:-0} + elapsed_ms))
    update_state_field "TOTAL_ELAPSED_MS" "$new_total"

    # Escape for JSON
    local escaped_item escaped_summary
    escaped_item=$(printf '%s' "${CURRENT_ITEM:-}" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    escaped_summary=$(printf '%s' "$summary" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')

    # Write end entry to iteration history
    local history_entry
    history_entry="{\"iteration\":${LOOP_ITERATION:-0},\"item\":\"$escaped_item\",\"ended\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"status\":\"$status\",\"elapsed_ms\":$elapsed_ms,\"summary\":\"$escaped_summary\"}"

    echo "$history_entry" >> "$work_dir/.iteration-history.jsonl"

    # Warn if iteration took too long (>5 minutes = 300000ms)
    if [[ $elapsed_ms -gt 300000 ]]; then
        log_warn "Iteration $LOOP_ITERATION took ${elapsed_ms}ms (>5 min)" 2>/dev/null || true
    fi

    log_debug "Iteration $LOOP_ITERATION ended: $status (${elapsed_ms}ms)" 2>/dev/null || true
}

# Get total elapsed time across all iterations
get_total_elapsed() {
    read_loop_state
    echo "${TOTAL_ELAPSED_MS:-0}"
}

# === Loop Status Summary ===

get_loop_status() {
    read_loop_state

    echo "Loop Status:"
    echo "  Active: $LOOP_ACTIVE"
    echo "  Iteration: $LOOP_ITERATION / $LOOP_MAX_ITERATIONS"
    echo "  Consecutive Errors: $CONSECUTIVE_ERRORS / ${ERROR_THRESHOLD:-$DEFAULT_ERROR_THRESHOLD}"
    echo "  WAITING Count: ${WAITING_COUNT:-0} / ${WAITING_THRESHOLD:-$DEFAULT_WAITING_THRESHOLD}"
    if [[ -n "$CURRENT_ITEM" ]]; then
        echo "  Current Item: $CURRENT_ITEM"
    fi
    if [[ -n "$LAST_STATUS" ]]; then
        echo "  Last Status: $LAST_STATUS"
    fi
    if [[ -n "$LOOP_PROMPT" ]]; then
        echo "  Prompt: $LOOP_PROMPT"
    fi
    if [[ -n "$LOOP_STARTED" ]]; then
        echo "  Started: $LOOP_STARTED"
    fi
    if [[ -n "$LAST_UPDATE" ]]; then
        echo "  Last Update: $LAST_UPDATE"
    fi
    if [[ ${TOTAL_ELAPSED_MS:-0} -gt 0 ]]; then
        echo "  Total Runtime: ${TOTAL_ELAPSED_MS}ms"
    fi
}

# Check if loop was interrupted (for crash recovery)
was_interrupted() {
    read_loop_state

    # If loop is active but we're in a new session, it was interrupted
    if [[ "$LOOP_ACTIVE" == "true" ]]; then
        # Check if current item is set but not completed
        if [[ -n "$CURRENT_ITEM" ]]; then
            return 0  # Likely interrupted
        fi
    fi

    return 1
}

# Command-line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        start)
            start_loop "${2:-}" "${3:-$DEFAULT_MAX_ITERATIONS}"
            ;;
        stop)
            stop_loop
            ;;
        status)
            get_loop_status
            ;;
        active)
            is_loop_active && echo "true" || echo "false"
            ;;
        iteration)
            get_iteration
            ;;
        increment)
            increment_iteration
            ;;
        errors)
            get_error_count
            ;;
        inc-errors)
            increment_errors
            ;;
        reset-errors)
            reset_errors
            echo "Errors reset to 0"
            ;;
        should-pause)
            should_pause && echo "true" || echo "false"
            ;;
        current-item)
            get_current_item
            ;;
        set-item)
            set_current_item "$2"
            echo "Current item: $2"
            ;;
        was-interrupted)
            was_interrupted && echo "true" || echo "false"
            ;;
        waiting)
            get_waiting_count
            ;;
        inc-waiting)
            increment_waiting
            ;;
        reset-waiting)
            reset_waiting
            echo "WAITING count reset to 0"
            ;;
        waiting-exceeded)
            waiting_threshold_exceeded && echo "true" || echo "false"
            ;;
        log-start)
            log_iteration_start
            echo "Iteration start logged"
            ;;
        log-end)
            log_iteration_end "${2:-UNKNOWN}" "${3:-}"
            echo "Iteration end logged: $2"
            ;;
        total-elapsed)
            get_total_elapsed
            ;;
        *)
            echo "Usage: $0 {start|stop|status|active|iteration|increment|errors|...}"
            echo ""
            echo "Loop Commands:"
            echo "  start [prompt] [max]  - Start loop"
            echo "  stop                  - Stop the loop"
            echo "  status                - Show loop status"
            echo "  active                - Check if loop is active"
            echo "  iteration             - Get current iteration"
            echo "  increment             - Increment iteration"
            echo ""
            echo "Error Tracking:"
            echo "  errors                - Get consecutive error count"
            echo "  inc-errors            - Increment error count"
            echo "  reset-errors          - Reset errors to 0"
            echo "  should-pause          - Check if should pause"
            echo ""
            echo "WAITING Tracking:"
            echo "  waiting               - Get consecutive WAITING count"
            echo "  inc-waiting           - Increment WAITING count"
            echo "  reset-waiting         - Reset WAITING count to 0"
            echo "  waiting-exceeded      - Check if threshold exceeded"
            echo ""
            echo "Iteration History:"
            echo "  log-start             - Log iteration start"
            echo "  log-end <status> [summary] - Log iteration end"
            echo "  total-elapsed         - Get total elapsed ms"
            echo ""
            echo "Item Tracking:"
            echo "  current-item          - Get current item ID"
            echo "  set-item <id>         - Set current item"
            echo "  was-interrupted       - Check if loop was interrupted"
            ;;
    esac
fi
