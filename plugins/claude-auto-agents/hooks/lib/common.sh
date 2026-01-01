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
            local lock_mtime lock_age
            # macOS uses -f %m, Linux uses -c %Y
            if [[ "$(uname)" == "Darwin" ]]; then
                lock_mtime=$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0)
            else
                lock_mtime=$(stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
            fi
            lock_age=$(( $(date +%s) - lock_mtime ))
            if [[ $lock_age -gt 60 ]]; then
                log_debug "Removing stale lock: $LOCK_DIR (age: ${lock_age}s)"
                rm -rf "$LOCK_DIR"
                continue
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

# Debug log (only if CLAUDE_DEBUG is set)
log_debug() {
    local message="$1"
    local log_file
    log_file="$(get_work_dir)/.debug.log"

    # Always log if debug file exists or CLAUDE_DEBUG is set
    if [[ -n "${CLAUDE_DEBUG:-}" ]] || [[ -f "$log_file" ]]; then
        echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$$] $message" >> "$log_file"
    fi
}

# Info log (always logged to .loop.log)
log_info() {
    local message="$1"
    local log_file
    log_file="$(get_work_dir)/.loop.log"

    mkdir -p "$(dirname "$log_file")"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $message" >> "$log_file"
}

# Error log
log_error() {
    local message="$1"
    log_info "ERROR: $message"
    log_debug "ERROR: $message"
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
export -f log_debug log_info log_error
export -f get_timestamp is_file_stale
