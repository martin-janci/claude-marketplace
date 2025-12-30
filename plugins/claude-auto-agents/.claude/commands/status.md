---
description: Show current loop progress and queue status
---

# /status - Check Status

Show the current status of the autonomous loop and work queue.

## Usage

```
/status
```

## Output

Displays:
- Loop state (active/inactive, iteration count)
- Queue summary (pending, in progress, blocked)
- Current work context
- Recent history

!bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/lib/loop-control.sh status && echo "" && "$CLAUDE_PROJECT_DIR"/.claude/hooks/lib/queue-manager.sh summary

## Information Shown

### Loop Status
- Active: Whether loop is running
- Iteration: Current iteration number
- Max: Maximum allowed iterations
- Started: When loop began

### Queue Summary
- In Progress: Items being worked on
- Pending: Items waiting
- Blocked: Items that cannot proceed

### Current Work
Shows contents of `work/current.md` if active work exists.

## Related Commands

- `/loop` - Start the loop
- `/stop` - Stop the loop
- `/queue list` - See full queue
