#!/bin/bash
# queue-manager.sh - Markdown work queue management
#
# CRUD operations for work/queue.md with:
# - File locking to prevent race conditions
# - Robust item extraction using awk
# - Dependency checking
# - Section-aware counting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh" 2>/dev/null || true

# Get project directory using common.sh or fallback
PROJECT_DIR="$(get_project_dir 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}")"
WORK_DIR="$PROJECT_DIR/work"
QUEUE_FILE="$WORK_DIR/queue.md"
HISTORY_FILE="$WORK_DIR/history.md"
BLOCKERS_FILE="$WORK_DIR/blockers.md"

# Initialize queue file if missing
init_queue() {
    mkdir -p "$WORK_DIR"

    if [[ ! -f "$QUEUE_FILE" ]]; then
        cat > "$QUEUE_FILE" << 'EOF'
# Work Queue

## In Progress

## Pending

## Blocked

## Completed
EOF
    fi

    # Initialize history file
    if [[ ! -f "$HISTORY_FILE" ]]; then
        cat > "$HISTORY_FILE" << 'EOF'
# Work History

## Completed Items

| Date | ID | Summary | Agent | Iterations |
|------|----|---------|-------|------------|
EOF
    fi

    # Initialize blockers file
    if [[ ! -f "$BLOCKERS_FILE" ]]; then
        cat > "$BLOCKERS_FILE" << 'EOF'
# Blocked Items

| ID | Reason | Since | Resolved |
|----|--------|-------|----------|
EOF
    fi
}

# === Section-aware counting (fixed) ===

# Count items in a specific section
count_items() {
    local section="${1:-Pending}"
    init_queue

    awk -v section="$section" '
        /^## / { current_section = substr($0, 4) }
        current_section == section && /^- \[ \]/ { count++ }
        END { print count + 0 }
    ' "$QUEUE_FILE"
}

# Check if queue is empty (no pending + no in-progress)
is_queue_empty() {
    local in_progress pending
    in_progress=$(count_items "In Progress")
    pending=$(count_items "Pending")

    [[ $((in_progress + pending)) -eq 0 ]]
}

# === Robust item extraction using awk ===

# Extract a single item with all its metadata
# Returns the item block including all indented lines
extract_item() {
    local id="$1"
    init_queue

    awk -v id="$id" '
        $0 ~ "\\[" id "\\]" {
            print
            capturing = 1
            next
        }
        capturing && /^  - / {
            print
            next
        }
        capturing {
            exit
        }
    ' "$QUEUE_FILE"
}

# Get item ID from item line
# Input: "- [ ] **[TASK-001]** Description here"
# Output: "TASK-001"
get_item_id() {
    local line="$1"
    echo "$line" | sed -n 's/.*\[\([^]]*\)\].*/\1/p' | head -1
}

# List all items in queue
list_queue() {
    init_queue
    cat "$QUEUE_FILE"
}

# Get next pending item (respects dependencies)
get_next_item() {
    init_queue

    # Get all pending items
    local items
    items=$(awk '
        /^## Pending/ { in_pending = 1; next }
        /^## / { in_pending = 0 }
        in_pending && /^- \[ \]/ { print }
    ' "$QUEUE_FILE")

    # For each item, check if dependencies are met
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue

        local item_id
        item_id=$(get_item_id "$item")

        if check_dependencies_met "$item_id"; then
            echo "$item"
            return 0
        fi
    done <<< "$items"

    # No items with met dependencies
    return 1
}

# === Dependency checking ===

# Check if an item's dependencies are all completed
check_dependencies_met() {
    local id="$1"

    # Extract the item to get its dependencies
    local item_block
    item_block=$(extract_item "$id")

    # Get depends line
    local depends
    depends=$(echo "$item_block" | grep "Depends:" | sed 's/.*Depends: *//')

    # If no dependencies, return true
    [[ -z "$depends" ]] && return 0

    # Check each dependency
    IFS=',' read -ra dep_array <<< "$depends"
    for dep in "${dep_array[@]}"; do
        dep=$(echo "$dep" | tr -d ' ')
        [[ -z "$dep" ]] && continue

        # Check if dependency is in Completed section or history
        if ! is_item_completed "$dep"; then
            log_debug "Dependency not met: $dep for $id" 2>/dev/null || true
            return 1
        fi
    done

    return 0
}

# Check if an item is completed
is_item_completed() {
    local id="$1"

    # Check in Completed section of queue
    if awk -v id="$id" '
        /^## Completed/ { in_completed = 1; next }
        /^## / { in_completed = 0 }
        in_completed && $0 ~ "\\[" id "\\]" { found = 1; exit }
        END { exit !found }
    ' "$QUEUE_FILE" 2>/dev/null; then
        return 0
    fi

    # Check in history file
    if [[ -f "$HISTORY_FILE" ]] && grep -q "\| $id \|" "$HISTORY_FILE" 2>/dev/null; then
        return 0
    fi

    return 1
}

# === Queue modifications (with locking) ===

# Add item to queue
add_item() {
    local id="$1"
    local description="$2"
    local priority="${3:-medium}"
    local agent="${4:-developer}"
    local depends="${5:-}"

    init_queue

    # Acquire lock for queue modifications
    if ! acquire_lock "queue" 10 2>/dev/null; then
        echo "Error: Could not acquire queue lock"
        return 1
    fi

    # Create a temp file with the new entry
    local tmpentry
    tmpentry=$(mktemp)
    {
        echo "- [ ] **[$id]** $description"
        echo "  - Priority: $priority"
        echo "  - Agent: $agent"
        [[ -n "$depends" ]] && echo "  - Depends: $depends"
    } > "$tmpentry"

    # Insert into Pending section
    awk -v entryfile="$tmpentry" '
        /^## Pending/ {
            print
            while ((getline line < entryfile) > 0) print line
            close(entryfile)
            next
        }
        { print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    rm -f "$tmpentry"
    release_lock 2>/dev/null || true
    log_info "Added to queue: [$id] $description" 2>/dev/null || true
    echo "Added: [$id] $description"
}

# Remove item from queue (by ID)
remove_item() {
    local id="$1"

    init_queue

    if ! acquire_lock "queue" 10 2>/dev/null; then
        echo "Error: Could not acquire queue lock"
        return 1
    fi

    # Remove item and its metadata lines
    awk -v id="$id" '
        $0 ~ "\\[" id "\\]" { skip = 1; next }
        skip && /^  - / { next }
        { skip = 0; print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    release_lock 2>/dev/null || true
    echo "Removed: [$id]"
}

# Move item to In Progress
start_item() {
    local id="$1"

    init_queue

    if ! acquire_lock "queue" 10 2>/dev/null; then
        echo "Error: Could not acquire queue lock"
        return 1
    fi

    # Check dependencies first
    if ! check_dependencies_met "$id"; then
        release_lock 2>/dev/null || true
        echo "Error: Dependencies not met for [$id]"
        return 1
    fi

    # Extract item using robust method
    local item
    item=$(extract_item "$id")

    if [[ -z "$item" ]]; then
        release_lock 2>/dev/null || true
        echo "Item not found: [$id]"
        return 1
    fi

    # Add timestamp
    local timestamp
    timestamp=$(get_timestamp 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create temp file with the new item (first line + Started + rest)
    local tmpentry
    tmpentry=$(mktemp)
    {
        echo "$item" | head -1
        echo "  - Started: $timestamp"
        echo "$item" | tail -n +2
    } > "$tmpentry"

    # Remove from current location
    awk -v id="$id" '
        $0 ~ "\\[" id "\\]" { skip = 1; next }
        skip && /^  - / { next }
        { skip = 0; print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    # Add to In Progress section
    awk -v entryfile="$tmpentry" '
        /^## In Progress/ {
            print
            while ((getline line < entryfile) > 0) print line
            close(entryfile)
            next
        }
        { print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    rm -f "$tmpentry"
    release_lock 2>/dev/null || true
    log_info "Started: [$id]" 2>/dev/null || true
    echo "Started: [$id]"
}

# Complete item
complete_item() {
    local id="$1"
    local summary="${2:-Completed}"
    local agent="${3:-}"
    local iterations="${4:-1}"

    init_queue

    if ! acquire_lock "queue" 10 2>/dev/null; then
        echo "Error: Could not acquire queue lock"
        return 1
    fi

    # Remove from queue
    awk -v id="$id" '
        $0 ~ "\\[" id "\\]" { skip = 1; next }
        skip && /^  - / { next }
        { skip = 0; print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    # Add to history
    local timestamp
    timestamp=$(get_timestamp 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "| $timestamp | $id | $summary | $agent | $iterations |" >> "$HISTORY_FILE"

    release_lock 2>/dev/null || true
    log_info "Completed: [$id] - $summary" 2>/dev/null || true
    echo "Completed: [$id]"
}

# Block item
block_item() {
    local id="$1"
    local reason="$2"

    init_queue

    if ! acquire_lock "queue" 10 2>/dev/null; then
        echo "Error: Could not acquire queue lock"
        return 1
    fi

    # Extract item
    local item
    item=$(extract_item "$id")

    if [[ -z "$item" ]]; then
        release_lock 2>/dev/null || true
        echo "Item not found: [$id]"
        return 1
    fi

    local timestamp
    timestamp=$(get_timestamp 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Create temp file with the blocked item
    local tmpentry
    tmpentry=$(mktemp)
    {
        echo "$item" | head -1
        echo "  - Blocker: $reason"
        echo "  - Since: $timestamp"
        echo "$item" | tail -n +2
    } > "$tmpentry"

    # Remove from current location
    awk -v id="$id" '
        $0 ~ "\\[" id "\\]" { skip = 1; next }
        skip && /^  - / { next }
        { skip = 0; print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    # Add to Blocked section
    awk -v entryfile="$tmpentry" '
        /^## Blocked/ {
            print
            while ((getline line < entryfile) > 0) print line
            close(entryfile)
            next
        }
        { print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    rm -f "$tmpentry"

    # Log to blockers file
    echo "| $id | $reason | $timestamp | - |" >> "$BLOCKERS_FILE"

    release_lock 2>/dev/null || true
    log_info "Blocked: [$id] - $reason" 2>/dev/null || true
    echo "Blocked: [$id] - $reason"
}

# Unblock item (move back to Pending)
unblock_item() {
    local id="$1"

    init_queue

    if ! acquire_lock "queue" 10 2>/dev/null; then
        echo "Error: Could not acquire queue lock"
        return 1
    fi

    # Extract item from Blocked section
    local item
    item=$(extract_item "$id")

    if [[ -z "$item" ]]; then
        release_lock 2>/dev/null || true
        echo "Item not found: [$id]"
        return 1
    fi

    # Create temp file with item (minus blocker metadata)
    local tmpentry
    tmpentry=$(mktemp)
    echo "$item" | grep -v "Blocker:\|Since:" > "$tmpentry"

    # Remove from Blocked
    awk -v id="$id" '
        $0 ~ "\\[" id "\\]" { skip = 1; next }
        skip && /^  - / { next }
        { skip = 0; print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    # Add to Pending
    awk -v entryfile="$tmpentry" '
        /^## Pending/ {
            print
            while ((getline line < entryfile) > 0) print line
            close(entryfile)
            next
        }
        { print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    rm -f "$tmpentry"

    release_lock 2>/dev/null || true
    log_info "Unblocked: [$id]" 2>/dev/null || true
    echo "Unblocked: [$id]"
}

# Get queue summary
queue_summary() {
    init_queue

    local in_progress pending blocked
    in_progress=$(count_items "In Progress")
    pending=$(count_items "Pending")
    blocked=$(count_items "Blocked")

    echo "Queue Summary:"
    echo "  In Progress: $in_progress"
    echo "  Pending: $pending"
    echo "  Blocked: $blocked"
    echo ""

    if [[ $((in_progress + pending)) -eq 0 ]]; then
        echo "Queue is empty."
    else
        echo "Next item:"
        get_next_item || echo "  No items with met dependencies"
    fi
}

# Command-line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        list)
            list_queue
            ;;
        count)
            count_items "${2:-Pending}"
            ;;
        is-empty)
            is_queue_empty && echo "true" || echo "false"
            ;;
        next)
            get_next_item || echo "No available items"
            ;;
        add)
            add_item "$2" "$3" "${4:-medium}" "${5:-developer}" "${6:-}"
            ;;
        remove)
            remove_item "$2"
            ;;
        start)
            start_item "$2"
            ;;
        complete)
            complete_item "$2" "$3" "$4" "$5"
            ;;
        block)
            block_item "$2" "$3"
            ;;
        unblock)
            unblock_item "$2"
            ;;
        deps-met)
            check_dependencies_met "$2" && echo "true" || echo "false"
            ;;
        summary)
            queue_summary
            ;;
        *)
            echo "Usage: $0 {list|count|is-empty|next|add|remove|start|complete|block|unblock|deps-met|summary}"
            echo ""
            echo "Query Commands:"
            echo "  list                    - Show full queue"
            echo "  count [section]         - Count items in section"
            echo "  is-empty                - Check if queue is empty"
            echo "  next                    - Get next pending item (respects deps)"
            echo "  deps-met <id>           - Check if dependencies are met"
            echo "  summary                 - Show queue summary"
            echo ""
            echo "Modification Commands:"
            echo "  add <id> <desc> [priority] [agent] [depends]"
            echo "  remove <id>             - Remove item from queue"
            echo "  start <id>              - Move item to In Progress"
            echo "  complete <id> [summary] [agent] [iterations]"
            echo "  block <id> <reason>     - Block item with reason"
            echo "  unblock <id>            - Move blocked item to Pending"
            ;;
    esac
fi
