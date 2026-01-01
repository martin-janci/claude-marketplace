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
EOF
}

# Update a single field in state
update_state_field() {
    local field="$1"
    local value="$2"

    read_loop_state

    # Ensure ERROR_THRESHOLD has a default if not set from state file
    ERROR_THRESHOLD="${ERROR_THRESHOLD:-$DEFAULT_ERROR_THRESHOLD}"

    case "$field" in
        LOOP_ACTIVE) LOOP_ACTIVE="$value" ;;
        LOOP_ITERATION) LOOP_ITERATION="$value" ;;
        CONSECUTIVE_ERRORS) CONSECUTIVE_ERRORS="$value" ;;
        CURRENT_ITEM) CURRENT_ITEM="$value" ;;
        LAST_STATUS) LAST_STATUS="$value" ;;
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

# === Loop Status Summary ===

get_loop_status() {
    read_loop_state

    echo "Loop Status:"
    echo "  Active: $LOOP_ACTIVE"
    echo "  Iteration: $LOOP_ITERATION / $LOOP_MAX_ITERATIONS"
    echo "  Consecutive Errors: $CONSECUTIVE_ERRORS / $ERROR_THRESHOLD"
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
            echo "Item Tracking:"
            echo "  current-item          - Get current item ID"
            echo "  set-item <id>         - Set current item"
            echo "  was-interrupted       - Check if loop was interrupted"
            ;;
    esac
fi
