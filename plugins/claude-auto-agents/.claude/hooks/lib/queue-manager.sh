#!/bin/bash
# queue-manager.sh - Markdown work queue management
#
# CRUD operations for work/queue.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
QUEUE_FILE="$PROJECT_DIR/work/queue.md"
HISTORY_FILE="$PROJECT_DIR/work/history.md"
CURRENT_FILE="$PROJECT_DIR/work/current.md"
BLOCKERS_FILE="$PROJECT_DIR/work/blockers.md"

# Initialize queue file if missing
init_queue() {
    if [[ ! -f "$QUEUE_FILE" ]]; then
        mkdir -p "$(dirname "$QUEUE_FILE")"
        cat > "$QUEUE_FILE" << 'EOF'
# Work Queue

## In Progress

## Pending

## Blocked

## Completed
EOF
    fi
}

# List all items in queue
list_queue() {
    init_queue
    cat "$QUEUE_FILE"
}

# Count items by section
count_items() {
    local section="${1:-Pending}"
    init_queue

    # Count checkbox items in section
    awk -v section="$section" '
        /^## / { current_section = substr($0, 4) }
        current_section == section && /^- \[ \]/ { count++ }
        END { print count + 0 }
    ' "$QUEUE_FILE"
}

# Get next pending item
get_next_item() {
    init_queue

    # Get first checkbox item from Pending section
    awk '
        /^## Pending/ { in_pending = 1; next }
        /^## / { in_pending = 0 }
        in_pending && /^- \[ \]/ { print; exit }
    ' "$QUEUE_FILE"
}

# Add item to queue
add_item() {
    local id="$1"
    local description="$2"
    local priority="${3:-medium}"
    local agent="${4:-developer}"
    local depends="${5:-}"

    init_queue

    # Create item entry
    local entry="- [ ] **[$id]** $description"
    entry+="\n  - Priority: $priority"
    entry+="\n  - Agent: $agent"
    [[ -n "$depends" ]] && entry+="\n  - Depends: $depends"

    # Insert into Pending section
    # Use awk to insert after "## Pending" line
    awk -v entry="$entry" '
        /^## Pending/ { print; print entry; next }
        { print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    echo "Added: [$id] $description"
}

# Remove item from queue
remove_item() {
    local id="$1"

    init_queue

    # Remove lines matching the ID and its metadata (indented lines following)
    awk -v id="$id" '
        /^\- \[ \].*\['"$id"'\]/ { skip = 1; next }
        skip && /^  -/ { next }
        { skip = 0; print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    echo "Removed: [$id]"
}

# Move item to In Progress
start_item() {
    local id="$1"

    init_queue

    # Extract item from Pending
    local item=$(grep -A5 "\[$id\]" "$QUEUE_FILE" | head -6)

    if [[ -z "$item" ]]; then
        echo "Item not found: [$id]"
        return 1
    fi

    # Add timestamp
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    item=$(echo "$item" | sed "s/- Priority:/- Started: $timestamp\n  - Priority:/")

    # Remove from current location
    remove_item "$id"

    # Add to In Progress
    awk -v entry="$item" '
        /^## In Progress/ { print; print entry; next }
        { print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    echo "Started: [$id]"
}

# Complete item
complete_item() {
    local id="$1"
    local summary="${2:-Completed}"
    local agent="${3:-}"
    local iterations="${4:-1}"

    init_queue

    # Remove from queue
    remove_item "$id"

    # Add to history
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "| $timestamp | $id | $summary | $agent | $iterations |" >> "$HISTORY_FILE"

    echo "Completed: [$id]"
}

# Block item
block_item() {
    local id="$1"
    local reason="$2"

    init_queue

    # Extract item
    local item=$(grep -A5 "\[$id\]" "$QUEUE_FILE" | head -6)

    if [[ -z "$item" ]]; then
        echo "Item not found: [$id]"
        return 1
    fi

    # Add blocker info
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    item=$(echo "$item" | sed "s/- Priority:/- Blocker: $reason\n  - Since: $timestamp\n  - Priority:/")

    # Remove from current location
    remove_item "$id"

    # Add to Blocked
    awk -v entry="$item" '
        /^## Blocked/ { print; print entry; next }
        { print }
    ' "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    # Log to blockers file
    echo "| $id | $reason | $timestamp | - |" >> "$BLOCKERS_FILE"

    echo "Blocked: [$id] - $reason"
}

# Get queue summary
queue_summary() {
    init_queue

    local in_progress=$(count_items "In Progress")
    local pending=$(count_items "Pending")
    local blocked=$(count_items "Blocked")

    echo "Queue Summary:"
    echo "  In Progress: $in_progress"
    echo "  Pending: $pending"
    echo "  Blocked: $blocked"
    echo ""
    echo "Next item:"
    get_next_item
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
        next)
            get_next_item
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
        summary)
            queue_summary
            ;;
        *)
            echo "Usage: $0 {list|count|next|add|remove|start|complete|block|summary}"
            echo ""
            echo "Commands:"
            echo "  list                    - Show full queue"
            echo "  count [section]         - Count items in section"
            echo "  next                    - Get next pending item"
            echo "  add <id> <desc> [priority] [agent] [depends]"
            echo "                          - Add new item to Pending"
            echo "  remove <id>             - Remove item from queue"
            echo "  start <id>              - Move item to In Progress"
            echo "  complete <id> [summary] [agent] [iterations]"
            echo "                          - Complete and move to history"
            echo "  block <id> <reason>     - Block item with reason"
            echo "  summary                 - Show queue summary"
            ;;
    esac
fi
