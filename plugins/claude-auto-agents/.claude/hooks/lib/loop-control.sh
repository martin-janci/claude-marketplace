#!/bin/bash
# loop-control.sh - Loop iteration tracking and control
#
# Manages the autonomous loop state: active/inactive, iteration count, limits

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_STATE_FILE="$SCRIPT_DIR/.loop-state"

# Default values
DEFAULT_MAX_ITERATIONS=50

# Initialize loop state file if missing
init_loop_state() {
    if [[ ! -f "$LOOP_STATE_FILE" ]]; then
        cat > "$LOOP_STATE_FILE" << EOF
LOOP_ACTIVE=false
LOOP_ITERATION=0
LOOP_MAX_ITERATIONS=$DEFAULT_MAX_ITERATIONS
LOOP_PROMPT=""
LOOP_STARTED=""
EOF
    fi
}

# Read current loop state
read_loop_state() {
    init_loop_state
    source "$LOOP_STATE_FILE"
}

# Update loop state
update_loop_state() {
    local active="${1:-false}"
    local iteration="${2:-0}"
    local prompt="${3:-}"
    local max_iterations="${4:-$DEFAULT_MAX_ITERATIONS}"
    local started="${5:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

    cat > "$LOOP_STATE_FILE" << EOF
LOOP_ACTIVE=$active
LOOP_ITERATION=$iteration
LOOP_MAX_ITERATIONS=$max_iterations
LOOP_PROMPT="$prompt"
LOOP_STARTED="$started"
EOF
}

# Start a new loop
start_loop() {
    local prompt="$1"
    local max_iterations="${2:-$DEFAULT_MAX_ITERATIONS}"

    update_loop_state "true" "0" "$prompt" "$max_iterations" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Loop started with prompt: $prompt"
    echo "Max iterations: $max_iterations"
}

# Stop the loop
stop_loop() {
    read_loop_state
    local final_iteration="$LOOP_ITERATION"

    update_loop_state "false" "0" "" "$LOOP_MAX_ITERATIONS" ""
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
    update_loop_state "$LOOP_ACTIVE" "$new_iteration" "$LOOP_PROMPT" "$LOOP_MAX_ITERATIONS" "$LOOP_STARTED"
    echo "$new_iteration"
}

# Check if at iteration limit
at_limit() {
    read_loop_state
    [[ $LOOP_ITERATION -ge $LOOP_MAX_ITERATIONS ]]
}

# Get loop status summary
get_loop_status() {
    read_loop_state

    echo "Loop Status:"
    echo "  Active: $LOOP_ACTIVE"
    echo "  Iteration: $LOOP_ITERATION / $LOOP_MAX_ITERATIONS"
    if [[ -n "$LOOP_PROMPT" ]]; then
        echo "  Prompt: $LOOP_PROMPT"
    fi
    if [[ -n "$LOOP_STARTED" ]]; then
        echo "  Started: $LOOP_STARTED"
    fi
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
        *)
            echo "Usage: $0 {start|stop|status|active|iteration|increment}"
            echo ""
            echo "Commands:"
            echo "  start [prompt] [max]  - Start loop with prompt and max iterations"
            echo "  stop                  - Stop the loop"
            echo "  status                - Show loop status"
            echo "  active                - Check if loop is active (returns true/false)"
            echo "  iteration             - Get current iteration number"
            echo "  increment             - Increment and return iteration"
            ;;
    esac
fi
