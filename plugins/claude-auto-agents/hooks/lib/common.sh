#!/bin/bash
# common.sh - Shared utilities for all hook scripts
#
# Provides:
# - Unified path resolution (PROJECT_DIR, WORK_DIR)
# - Portable file locking with stale detection
# - Atomic file writes
# - Debug logging

# === Path Resolution (unified) ===

# Get the project directory - single source of truth
get_project_dir() {
    if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
        echo "$CLAUDE_PROJECT_DIR"
    elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
        echo "$CLAUDE_PLUGIN_ROOT"
    else
        git rev-parse --show-toplevel 2>/dev/null || pwd
    fi
}

# Get work directory
get_work_dir() {
    echo "$(get_project_dir)/work"
}

# Ensure work directory exists
ensure_work_dir() {
    local work_dir
    work_dir="$(get_work_dir)"
    mkdir -p "$work_dir"
    echo "$work_dir"
}

# === File Locking (portable, with stale detection) ===

# Global to track our lock for cleanup
LOCK_DIR=""

# Acquire a lock by name
# Usage: acquire_lock "queue" [timeout_seconds]
# Returns: 0 on success, 1 on timeout
acquire_lock() {
    local name="${1:-queue}"
    local timeout="${2:-10}"
    LOCK_DIR="$(get_work_dir)/.lock-$name"

    local start_time
    start_time=$(date +%s)

    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        # Check for stale lock (>60 seconds old)
        if [[ -d "$LOCK_DIR" ]]; then
            local lock_mtime lock_age lock_pid
            # macOS uses -f %m, Linux uses -c %Y
            if [[ "$(uname)" == "Darwin" ]]; then
                lock_mtime=$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0)
            else
                lock_mtime=$(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
            fi
            lock_age=$(( $(date +%s) - lock_mtime ))

            # Check if lock is stale (old) AND holder is not running
            if [[ $lock_age -gt 60 ]]; then
                # Try to read the PID of the lock holder
                if [[ -f "$LOCK_DIR/pid" ]]; then
                    lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
                    # If PID exists and process is still running, don't remove
                    if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
                        log_debug "Lock held by running process $lock_pid, waiting..."
                    else
                        log_debug "Removing stale lock: $LOCK_DIR (age: ${lock_age}s, dead PID: $lock_pid)"
                        rm -rf "$LOCK_DIR"
                        continue
                    fi
                else
                    # No PID file, safe to remove stale lock
                    log_debug "Removing stale lock: $LOCK_DIR (age: ${lock_age}s, no PID)"
                    rm -rf "$LOCK_DIR"
                    continue
                fi
            fi
        fi

        # Check timeout
        if [[ $(( $(date +%s) - start_time )) -ge $timeout ]]; then
            log_debug "Lock acquisition timeout: $name"
            return 1
        fi

        sleep 0.1
    done

    # Write our PID for debugging
    echo $$ > "$LOCK_DIR/pid"

    # Set trap to clean up on exit
    trap 'release_lock' EXIT

    log_debug "Acquired lock: $name (PID: $$)"
    return 0
}

# Release the current lock
release_lock() {
    if [[ -n "$LOCK_DIR" && -d "$LOCK_DIR" ]]; then
        rm -rf "$LOCK_DIR"
        log_debug "Released lock: $LOCK_DIR"
        LOCK_DIR=""
    fi
}

# === Atomic File Operations ===

# Atomic write to file (write to temp, then mv)
# Usage: atomic_write "content" "filepath"
atomic_write() {
    local content="$1"
    local filepath="$2"
    local tmpfile="${filepath}.tmp.$$"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$filepath")"

    # Write to temp file
    echo "$content" > "$tmpfile"

    # Atomic move
    mv "$tmpfile" "$filepath"
}

# Atomic append to file (with lock)
# Usage: atomic_append "line" "filepath"
atomic_append() {
    local line="$1"
    local filepath="$2"

    acquire_lock "$(basename "$filepath")" 5 || return 1
    echo "$line" >> "$filepath"
    release_lock
}

# === Logging ===

# Log levels (exported for use by other scripts)
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARN=2
export LOG_LEVEL_ERROR=3
export CURRENT_LOG_LEVEL=${CLAUDE_LOG_LEVEL:-1}  # Default: INFO

# Component name for structured logging (can be overridden)
COMPONENT="${COMPONENT:-common}"

# Structured log message
# Writes JSON to .agent-history.jsonl and optionally to .debug.log
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local work_dir
    work_dir="$(get_work_dir)"
    mkdir -p "$work_dir"

    # Escape message for JSON (basic escaping)
    local escaped_msg
    escaped_msg=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr '\n' ' ')

    # JSON-structured log entry
    local log_entry
    log_entry="{\"ts\":\"$timestamp\",\"pid\":$$,\"level\":\"$level\",\"component\":\"$COMPONENT\",\"msg\":\"$escaped_msg\"}"

    # Always write to structured log
    echo "$log_entry" >> "$work_dir/.agent-history.jsonl"

    # Conditionally write to debug log
    if [[ -n "${CLAUDE_DEBUG:-}" ]] || [[ -f "$work_dir/.debug.log" ]]; then
        printf "[%s] [%s] [%s] %s\n" "$timestamp" "$level" "$COMPONENT" "$message" >> "$work_dir/.debug.log"
    fi
}

# Debug log (only if CLAUDE_DEBUG is set)
log_debug() {
    local message="$1"
    log_message "DEBUG" "$message"
}

# Info log (always logged to .loop.log)
log_info() {
    local message="$1"
    local log_file
    log_file="$(get_work_dir)/.loop.log"

    mkdir -p "$(dirname "$log_file")"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $message" >> "$log_file"

    # Also log to structured log
    log_message "INFO" "$message"
}

# Warning log
log_warn() {
    local message="$1"
    log_info "WARN: $message"
    log_message "WARN" "$message"
}

# Error log
log_error() {
    local message="$1"
    log_info "ERROR: $message"
    log_message "ERROR" "$message"
}

# === Elapsed Time Tracking ===

# Timer start time (milliseconds if available, seconds as fallback)
TIMER_START=""

# Get current time in milliseconds (portable - macOS doesn't support %N)
get_time_ms() {
    local test_output
    test_output=$(date +%s%3N 2>/dev/null)
    # If the output contains 'N', the format wasn't supported
    if [[ "$test_output" == *"N"* ]] || [[ -z "$test_output" ]]; then
        echo "$(($(date +%s) * 1000))"
    else
        echo "$test_output"
    fi
}

# Start a timer for operation tracking
start_timer() {
    TIMER_START=$(get_time_ms)
}

# Get elapsed time in milliseconds since start_timer
elapsed_ms() {
    local now
    now=$(get_time_ms)
    echo $((now - ${TIMER_START:-now}))
}

# Log operation with elapsed time
# Usage: log_operation "operation_name" "status" ["details"]
log_operation() {
    local operation="$1"
    local status="$2"
    local details="${3:-}"
    local elapsed
    elapsed=$(elapsed_ms)

    log_info "$operation: $status (${elapsed}ms)${details:+ - $details}"
}

# === Utilities ===

# Get current ISO timestamp
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Check if file is stale (older than N seconds)
# Usage: is_file_stale "filepath" [max_age_seconds]
is_file_stale() {
    local filepath="$1"
    local max_age="${2:-300}"  # Default 5 minutes

    if [[ ! -f "$filepath" ]]; then
        return 0  # Non-existent is considered stale
    fi

    local file_mtime file_age
    if [[ "$(uname)" == "Darwin" ]]; then
        file_mtime=$(stat -f %m "$filepath" 2>/dev/null || echo 0)
    else
        file_mtime=$(stat -c %Y "$filepath" 2>/dev/null || echo 0)
    fi
    file_age=$(( $(date +%s) - file_mtime ))

    [[ $file_age -gt $max_age ]]
}

# Export functions for use in sourced scripts
export -f get_project_dir get_work_dir ensure_work_dir
export -f acquire_lock release_lock
export -f atomic_write atomic_append
export -f log_message log_debug log_info log_warn log_error
export -f get_time_ms start_timer elapsed_ms log_operation
export -f get_timestamp is_file_stale
