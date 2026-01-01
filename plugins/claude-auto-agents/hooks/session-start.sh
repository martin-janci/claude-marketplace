#!/bin/bash
# session-start.sh - Protocol injection, queue loading, and crash recovery
#
# This hook runs at the start of every Claude Code session.
# It injects the STATUS protocol, loads the current work queue,
# and detects if a previous session was interrupted.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set component name for structured logging
COMPONENT="session-start"

# Source library functions with error handling
# shellcheck source=lib/common.sh
if ! source "$SCRIPT_DIR/lib/common.sh" 2>/dev/null; then
    # Minimal fallback if common.sh fails to load
    log_info() { :; }
    log_debug() { :; }
    log_warn() { :; }
    log_error() { :; }
    get_project_dir() { echo "${CLAUDE_PROJECT_DIR:-$(pwd)}"; }
fi
# shellcheck source=lib/loop-control.sh
if ! source "$SCRIPT_DIR/lib/loop-control.sh" 2>/dev/null; then
    log_warn "Failed to source loop-control.sh"
fi
# shellcheck source=lib/queue-manager.sh
if ! source "$SCRIPT_DIR/lib/queue-manager.sh" 2>/dev/null; then
    log_warn "Failed to source queue-manager.sh"
fi

log_debug "Session start hook initialized"

# Get project directory
PROJECT_DIR="$(get_project_dir 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-$(pwd)}")"
WORK_DIR="$PROJECT_DIR/work"

log_debug "WORK_DIR: $WORK_DIR"

# Initialize work directory if it doesn't exist
init_work_directory() {
    if [[ ! -d "$WORK_DIR" ]]; then
        mkdir -p "$WORK_DIR"

        # Create queue.md
        cat > "$WORK_DIR/queue.md" << 'QUEUE'
# Work Queue

## In Progress
<!-- Items currently being worked on -->

## Pending
<!-- Items waiting to be picked up -->

## Blocked
<!-- Items that cannot proceed -->

## Completed
<!-- Reference - full history in history.md -->
QUEUE

        # Create history.md
        cat > "$WORK_DIR/history.md" << 'HISTORY'
# Work History

## Completed Items

| Date | ID | Summary | Agent | Iterations |
|------|----|---------|-------|------------|
HISTORY

        # Create current.md
        printf "# Current Work\n\nNo work in progress.\n" > "$WORK_DIR/current.md"

        # Create blockers.md
        printf "# Blocked Items\n\nNo blocked items.\n" > "$WORK_DIR/blockers.md"
    fi
}

# Check for crash recovery scenarios
check_crash_recovery() {
    local needs_recovery="false"
    local recovery_reason=""

    # Check 1: Loop was active with a current item
    if was_interrupted 2>/dev/null; then
        needs_recovery="true"
        recovery_reason="Loop was active with an unfinished item"
    fi

    # Check 2: Stale .status file exists (work was in progress)
    local status_file="$WORK_DIR/.status"
    if [[ -f "$status_file" ]]; then
        if is_file_stale "$status_file" 300 2>/dev/null; then
            needs_recovery="true"
            recovery_reason="Stale STATUS file found (session may have crashed)"
        fi
    fi

    # Check 3: current.md has active work but queue shows nothing in progress
    local current_file="$WORK_DIR/current.md"
    if [[ -f "$current_file" ]]; then
        local current_content
        current_content=$(cat "$current_file" 2>/dev/null)
        if [[ "$current_content" != *"No work in progress"* ]]; then
            local in_progress_count
            in_progress_count=$(count_items "In Progress" 2>/dev/null || echo "0")
            if [[ "$in_progress_count" -eq 0 ]]; then
                needs_recovery="true"
                recovery_reason="current.md has work but queue shows nothing in progress"
            fi
        fi
    fi

    if [[ "$needs_recovery" == "true" ]]; then
        echo ""
        echo "## ⚠️ Crash Recovery Detected"
        echo ""
        echo "**Reason:** $recovery_reason"
        echo ""
        echo "Previous session may have ended unexpectedly."
        echo ""
        echo "**Recovery options:**"
        echo "- Run \`/status\` to see current state"
        echo "- Run \`/loop\` to resume autonomous work"
        echo "- Check \`work/current.md\` for context"
        echo ""

        # Log the recovery detection
        log_info "Crash recovery detected: $recovery_reason" 2>/dev/null || true
    fi
}

# Initialize work directory
init_work_directory

# Read loop state
read_loop_state 2>/dev/null || true

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

# Show loop status
if [[ "${LOOP_ACTIVE:-false}" == "true" ]]; then
    echo ""
    echo "**LOOP ACTIVE** - Iteration: ${LOOP_ITERATION:-0} / ${LOOP_MAX_ITERATIONS:-50}"
    if [[ -n "${CURRENT_ITEM:-}" ]]; then
        echo "Current item: $CURRENT_ITEM"
    fi
    if [[ -n "${LOOP_PROMPT:-}" ]]; then
        echo "Original task: $LOOP_PROMPT"
    fi
    echo ""
    echo "Consecutive errors: ${CONSECUTIVE_ERRORS:-0} / ${ERROR_THRESHOLD:-3}"
    echo "WAITING count: ${WAITING_COUNT:-0} / ${WAITING_THRESHOLD:-10}"
    echo ""
    echo "Continue working on the task. Emit STATUS when done."

    # Log iteration start for timing
    log_iteration_start 2>/dev/null || true
    log_info "Loop iteration ${LOOP_ITERATION:-0} starting"
else
    echo ""
    echo "Loop is **inactive**. Use \`/loop \"task\"\` to start."
fi

# Check for crash recovery
check_crash_recovery

# Show current work queue summary
QUEUE_FILE="$WORK_DIR/queue.md"
if [[ -f "$QUEUE_FILE" ]]; then
    echo ""
    echo "## Work Queue Summary"
    echo ""

    # Count items using the proper function
    IN_PROGRESS_COUNT=$(count_items "In Progress" 2>/dev/null || echo "0")
    PENDING_COUNT=$(count_items "Pending" 2>/dev/null || echo "0")
    BLOCKED_COUNT=$(count_items "Blocked" 2>/dev/null || echo "0")

    echo "- In Progress: $IN_PROGRESS_COUNT"
    echo "- Pending: $PENDING_COUNT"
    echo "- Blocked: $BLOCKED_COUNT"

    # Get next item (respects dependencies)
    NEXT_ITEM=$(get_next_item 2>/dev/null || echo "")
    if [[ -n "$NEXT_ITEM" ]]; then
        echo "- Next up: $NEXT_ITEM"
    elif [[ "$PENDING_COUNT" -gt 0 ]]; then
        echo "- Next up: (dependencies not met)"
    else
        echo "- Next up: None"
    fi
fi

# Show current work context if exists
CURRENT_FILE="$WORK_DIR/current.md"
if [[ -f "$CURRENT_FILE" ]] && [[ -s "$CURRENT_FILE" ]]; then
    CURRENT_CONTENT=$(head -20 "$CURRENT_FILE")
    if [[ "$CURRENT_CONTENT" != *"No work in progress"* ]]; then
        echo ""
        echo "## Active Work Context"
        echo ""
        echo "$CURRENT_CONTENT"
    fi
fi
