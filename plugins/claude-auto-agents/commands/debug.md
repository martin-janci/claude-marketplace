# /debug - Agent Debug Dashboard

Shows comprehensive debug information for diagnosing agent issues.

## Usage
/debug [component]

Components:
- `loop` - Loop state and iteration info
- `queue` - Queue status and item details
- `status` - Current STATUS file contents
- `history` - Recent iteration history
- `locks` - Lock status and staleness
- `errors` - Recent errors from logs
- `all` - Full diagnostic dump (default)

!bash cat << 'SCRIPT' | bash
#!/bin/bash
WORK_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/work"
COMPONENT="${1:-all}"

echo "# Agent Debug Dashboard"
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

show_loop() {
    echo "## Loop State"
    if [[ -f "$WORK_DIR/.loop-state" ]]; then
        while IFS= read -r line; do
            echo "  $line"
        done < "$WORK_DIR/.loop-state"
    else
        echo "  No active loop"
    fi
    echo ""
}

show_queue() {
    echo "## Queue Summary"
    if [[ -f "$WORK_DIR/queue.md" ]]; then
        # Count items in different sections
        in_progress=$(grep -c '^\- \[x\]' "$WORK_DIR/queue.md" 2>/dev/null || echo 0)
        pending=$(grep -c '^\- \[ \]' "$WORK_DIR/queue.md" 2>/dev/null || echo 0)
        blocked=$(grep -c 'Blocker:' "$WORK_DIR/queue.md" 2>/dev/null || echo 0)
        echo "  In Progress: $in_progress"
        echo "  Pending: $pending"
        echo "  Blocked: $blocked"
    else
        echo "  No queue file"
    fi
    echo ""
}

show_status() {
    echo "## Current STATUS"
    if [[ -f "$WORK_DIR/.status" ]]; then
        # Get file age
        if [[ "$(uname)" == "Darwin" ]]; then
            file_mtime=$(stat -f %m "$WORK_DIR/.status" 2>/dev/null || echo 0)
        else
            file_mtime=$(stat -c %Y "$WORK_DIR/.status" 2>/dev/null || echo 0)
        fi
        age=$(($(date +%s) - file_mtime))
        echo "  Age: ${age}s"
        while IFS= read -r line; do
            echo "  $line"
        done < "$WORK_DIR/.status"
    else
        echo "  No status file"
    fi
    echo ""
}

show_history() {
    echo "## Recent Iteration History (last 10)"
    if [[ -f "$WORK_DIR/.iteration-history.jsonl" ]]; then
        tail -10 "$WORK_DIR/.iteration-history.jsonl" | while IFS= read -r line; do
            echo "  $line"
        done
    else
        echo "  No history available"
    fi
    echo ""
}

show_locks() {
    echo "## Lock Status"
    found_locks=false
    for lock in "$WORK_DIR"/.lock-*; do
        if [[ -d "$lock" ]]; then
            found_locks=true
            name=$(basename "$lock")
            if [[ "$(uname)" == "Darwin" ]]; then
                lock_mtime=$(stat -f %m "$lock" 2>/dev/null || echo 0)
            else
                lock_mtime=$(stat -c %Y "$lock" 2>/dev/null || echo 0)
            fi
            age=$(($(date +%s) - lock_mtime))
            pid=$(cat "$lock/pid" 2>/dev/null || echo "unknown")
            alive="dead"
            if [[ "$pid" != "unknown" ]] && kill -0 "$pid" 2>/dev/null; then
                alive="alive"
            fi
            echo "  $name: pid=$pid ($alive), age=${age}s"
        fi
    done
    if [[ "$found_locks" == "false" ]]; then
        echo "  No active locks"
    fi
    echo ""
}

show_errors() {
    echo "## Recent Errors (last 10)"
    if [[ -f "$WORK_DIR/.debug.log" ]]; then
        grep -iE "error|warn|fail" "$WORK_DIR/.debug.log" 2>/dev/null | tail -10 | while IFS= read -r line; do
            echo "  $line"
        done
    else
        echo "  No debug log"
    fi
    echo ""
}

show_agent_history() {
    echo "## Recent Agent Activity (last 10)"
    if [[ -f "$WORK_DIR/.agent-history.jsonl" ]]; then
        tail -10 "$WORK_DIR/.agent-history.jsonl" | while IFS= read -r line; do
            echo "  $line"
        done
    else
        echo "  No agent history"
    fi
    echo ""
}

case "$COMPONENT" in
    loop) show_loop ;;
    queue) show_queue ;;
    status) show_status ;;
    history) show_history ;;
    locks) show_locks ;;
    errors) show_errors ;;
    agent) show_agent_history ;;
    all)
        show_loop
        show_queue
        show_status
        show_history
        show_locks
        show_errors
        ;;
    *)
        echo "Unknown component: $COMPONENT"
        echo ""
        echo "Available components: loop, queue, status, history, locks, errors, agent, all"
        ;;
esac
SCRIPT
