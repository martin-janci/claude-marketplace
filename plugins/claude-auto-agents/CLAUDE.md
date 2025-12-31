# Claude Auto-Agents

Minimalist autonomous agent framework using Claude Code hooks.

## STATUS Signal Protocol

**CRITICAL**: You MUST emit a STATUS signal at the end of every work unit.

### Format

```
STATUS: COMPLETE | BLOCKED | WAITING | ERROR
SUMMARY: Brief description of what was done (1-2 sentences)
FILES: comma-separated list of changed files
NEXT: Suggested next action (optional)
BLOCKER: Reason if BLOCKED (optional)
```

### Status Values

| Status | Meaning | Action |
|--------|---------|--------|
| `COMPLETE` | Work finished successfully | Pick next item from queue |
| `BLOCKED` | Cannot proceed, needs input | Log blocker, pause loop |
| `WAITING` | External dependency (CI, review) | Wait and retry later |
| `ERROR` | Failed, needs investigation | Log error, may escalate |

### Example

```
STATUS: COMPLETE
SUMMARY: Implemented JWT authentication with refresh tokens
FILES: src/auth/jwt.ts, src/middleware/auth.ts, tests/auth.test.ts
NEXT: Add password reset flow
```

## Work Queue

Work items are tracked in `work/queue.md`. The format is:

```markdown
## In Progress
- [ ] **[ID]** Task description
  - Agent: agent-type
  - Started: ISO timestamp
  - Iteration: count

## Pending
- [ ] **[ID]** Task description
  - Priority: low|medium|high|critical
  - Depends: comma-separated IDs (optional)

## Blocked
- [ ] **[ID]** Task description
  - Blocker: Reason
  - Since: ISO timestamp
```

## Agent Types

| Agent | Tools | Model | Use Case |
|-------|-------|-------|----------|
| `developer` | Bash,Read,Write,Edit,Glob,Grep,Task | sonnet | Feature implementation |
| `reviewer` | Bash,Read,Glob,Grep | sonnet | Code review (read-only) |
| `fixer` | Bash,Read,Write,Edit,Glob,Grep | sonnet | Fix issues/CI failures |
| `orchestrator` | All + Task | opus | Autonomous control |
| `explorer` | Read,Glob,Grep | haiku | Fast codebase exploration |
| `pr-shepherd` | All + Task | sonnet | PR lifecycle management (uses `gh workflow run approve-pr` to approve) |
| `conflict-resolver` | Bash,Read,Write,Edit | sonnet | Merge conflict resolution |

## Commands

- `/loop [task]` - Start autonomous iteration loop
- `/stop` - Gracefully stop the loop
- `/status` - Show current progress and queue
- `/queue add|remove|list [args]` - Manage work queue
- `/spawn <agent> [task]` - Launch specific agent type

## Loop Behavior

When `/loop` is active:
1. SessionStart hook injects this protocol
2. Claude picks next item from `work/queue.md`
3. Work is executed, STATUS signal emitted
4. Stop hook parses STATUS
5. If COMPLETE: update queue, continue
6. If BLOCKED/ERROR: log and pause
7. Repeat until queue empty or `/stop`

## Safety Limits

- **Max iterations**: 50 (configurable in `.claude/hooks/lib/loop-control.sh`)
- **Turn limit per item**: 30
- **Auto-pause on**: 3 consecutive errors, context limit warning

## Project Structure

```
work/
  queue.md      # Work items
  current.md    # Active work context
  history.md    # Completed items log
  blockers.md   # Blocked items + reasons
```

## Context Recovery

When Claude Code runs low on context, it automatically summarizes and continues. The loop handles this gracefully:

### Automatic Recovery

Session continues with summary injected. The `work/` files persist state across context resets.

### Manual Recovery

If loop breaks due to context:

```bash
# Check where you left off
cat work/current.md
cat work/queue.md

# Resume the loop
/loop
```

### Best Practices

1. **Commit frequently** - Changes persist to git
2. **Use work/ files** - State survives context resets
3. **Break large tasks** - Smaller queue items = less context per item
4. **Use /compact** - Proactively compact before context runs out
5. **Use /status** - Check progress before context gets low
