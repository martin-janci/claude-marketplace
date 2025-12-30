---
description: Start autonomous iteration loop
argument: task description to work on
---

# /loop - Start Autonomous Loop

Start the autonomous iteration loop to work on tasks continuously.

## Usage

```
/loop "implement user authentication"
/loop  # Continue from work/queue.md
```

## Behavior

1. Sets loop state to active
2. Reads next item from `work/queue.md` (or uses provided task)
3. Spawns appropriate agent based on task type
4. On completion, moves to next item
5. Continues until queue empty, blocked, or max iterations

## Options

- No arguments: Pick next from queue
- With task: Add task to queue and start

!bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/lib/loop-control.sh start "$1" 50

After starting, the orchestrator will take over. The Stop hook will manage continuations.

## Safety

- Max 50 iterations by default
- Pauses on BLOCKED or ERROR status
- Use `/stop` to gracefully exit
- Ctrl+C to force stop

## Example

```
/loop "implement the login page with tests"
```

This will:
1. Add task to queue
2. Spawn developer agent
3. On completion, spawn reviewer
4. Continue until done or blocked
