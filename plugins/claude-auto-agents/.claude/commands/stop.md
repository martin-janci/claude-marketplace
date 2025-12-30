---
description: Gracefully stop the autonomous loop
---

# /stop - Stop Loop

Gracefully stop the autonomous iteration loop.

## Usage

```
/stop
```

## Behavior

1. Sets loop state to inactive
2. Allows current work to complete
3. Logs final state to history
4. Returns control to user

!bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/lib/loop-control.sh stop

## Notes

- Current work will complete before stopping
- Queue state is preserved
- Use `/loop` to resume later
- Progress is logged to `work/history.md`

## After Stopping

- Review `work/queue.md` for pending items
- Check `work/history.md` for completed work
- Check `work/blockers.md` for any blocked items

## Alternative

- **Ctrl+C**: Force stop immediately (may interrupt current work)
- **/stop**: Graceful stop after current STATUS
