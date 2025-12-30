---
description: Manage work queue items
argument: action (list|add|remove|start|complete|block)
---

# /queue - Manage Work Queue

Add, remove, and manage items in the work queue.

## Usage

```
/queue list                           # Show full queue
/queue add FEAT-001 "Add login page"  # Add item
/queue remove FEAT-001                # Remove item
/queue start FEAT-001                 # Move to In Progress
/queue complete FEAT-001              # Mark as complete
/queue block FEAT-001 "Waiting for API"  # Mark as blocked
```

## Actions

### list
Show the full work queue with all sections.

!bash if [ "$1" = "list" ] || [ -z "$1" ]; then "$CLAUDE_PROJECT_DIR"/.claude/hooks/lib/queue-manager.sh list; fi

### add
Add a new item to the Pending section.

Arguments:
- ID: Unique identifier (e.g., FEAT-001, FIX-002)
- Description: What needs to be done
- Priority: low|medium|high|critical (default: medium)
- Agent: developer|fixer|reviewer (default: developer)
- Depends: Comma-separated IDs (optional)

!bash if [ "$1" = "add" ]; then "$CLAUDE_PROJECT_DIR"/.claude/hooks/lib/queue-manager.sh add "$2" "$3" "${4:-medium}" "${5:-developer}" "$6"; fi

### remove
Remove an item from the queue entirely.

!bash if [ "$1" = "remove" ]; then "$CLAUDE_PROJECT_DIR"/.claude/hooks/lib/queue-manager.sh remove "$2"; fi

### start
Move an item to In Progress section.

!bash if [ "$1" = "start" ]; then "$CLAUDE_PROJECT_DIR"/.claude/hooks/lib/queue-manager.sh start "$2"; fi

### complete
Mark an item as complete and move to history.

!bash if [ "$1" = "complete" ]; then "$CLAUDE_PROJECT_DIR"/.claude/hooks/lib/queue-manager.sh complete "$2" "$3"; fi

### block
Mark an item as blocked with a reason.

!bash if [ "$1" = "block" ]; then "$CLAUDE_PROJECT_DIR"/.claude/hooks/lib/queue-manager.sh block "$2" "$3"; fi

## Queue File Location

`work/queue.md`

## Format

```markdown
## In Progress
- [ ] **[ID]** Description
  - Started: timestamp
  - Agent: type

## Pending
- [ ] **[ID]** Description
  - Priority: level
  - Depends: IDs

## Blocked
- [ ] **[ID]** Description
  - Blocker: reason
  - Since: timestamp
```
