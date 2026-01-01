# Multi-Agent Patterns for Claude Code

Practical patterns for solving multi-agent problems with Claude Code.

## Core Challenges

| Challenge | Description |
|-----------|-------------|
| Task decomposition | Splitting workload into discrete sub-tasks |
| Coordination | Sharing results, avoiding conflicts, staying consistent |
| Context limitations | Individual agents have limited memory/context windows |

## Architectural Patterns

### 1. Orchestrator Pattern

Use a **meta-agent** (orchestrator) to plan and coordinate work:

```
┌─────────────────┐
│   Orchestrator  │  ← Maintains global view
└────────┬────────┘
         │
    ┌────┼────┐
    ▼    ▼    ▼
  Agent Agent Agent  ← Specialized subagents
```

**Implementation in claude-auto-agents:**
- `/spawn orchestrator "coordinate feature development"`
- Orchestrator uses Task tool to spawn subagents
- Collects STATUS signals from each

### 2. Specialized Subagents

Create sub-agents with specific roles instead of monolithic agents:

| Agent Type | Role | Tools |
|------------|------|-------|
| `developer` | Feature implementation | Bash,Read,Write,Edit |
| `reviewer` | Code review (read-only) | Bash,Read,Glob,Grep |
| `fixer` | Fix issues/CI failures | Bash,Read,Write,Edit |
| `explorer` | Fast codebase exploration | Read,Glob,Grep |

**Benefits:**
- Reduced context load per agent
- Improved reliability through specialization
- Easier debugging and logging

### 3. Communication Protocols

#### STATUS Signal Protocol

All agents emit on completion:

```
STATUS: COMPLETE | BLOCKED | WAITING | ERROR
SUMMARY: What was done (1-2 sentences)
FILES: Changed files (comma-separated)
NEXT: Suggested next action
BLOCKER: Reason if blocked
```

#### Shared State Repository

Use `work/` directory for state transfer:

```
work/
  queue.md      # Task queue (pending, in-progress, blocked)
  current.md    # Active work context
  history.md    # Completed items log
  blockers.md   # Blocked items + reasons
```

## Context Management Strategies

### 1. Context Compaction

Use `/compact` proactively before context runs low.

### 2. Summarization

Agents should emit concise summaries in STATUS signals. These persist across context resets.

### 3. Periodic Check-ins

Agents synchronize via `work/current.md` after completing significant work.

### 4. Artifact-Based Handoff

Leave artifacts (files, queue entries) for next agents:

```markdown
## In Progress
- [ ] **[TASK-1]** Implement login
  - Agent: developer
  - Started: 2024-01-01T10:00:00Z
  - Context: See work/current.md for details
```

## Practical Workflow

### Step-by-Step Multi-Agent Execution

1. **Define task** at high level
2. **Orchestrator splits** into subtasks with roles
3. **Spawn subagents** for each subtask
4. **Agents work**, emit STATUS signals
5. **Orchestrator integrates** outputs
6. **Repeat/refine** as required

### Example: Parallel Epic Implementation

```bash
# Orchestrator spawns 3 developer agents in parallel
/epics-parallel "7A" "8A" "9A"

# Each agent:
# 1. Works in isolated git worktree
# 2. Implements stories with TDD
# 3. Creates PR
# 4. Emits STATUS: COMPLETE

# Orchestrator:
# 1. Monitors all STATUS signals
# 2. Handles any BLOCKED agents
# 3. Coordinates PR merges
```

## Scaling Approach

### Start Small

1. Begin with 2-3 agents
2. Add observability and logging
3. Implement conflict detection
4. Gradually scale complexity

### Conflict Prevention

- **Git worktrees**: Isolate parallel work
- **File locks**: Prevent simultaneous edits
- **Queue management**: Avoid duplicate tasks

## Agent Coordination Patterns

### Sequential Chain

```
Agent A → Agent B → Agent C → Done
```

Use when tasks have dependencies.

### Parallel Fan-Out

```
    Orchestrator
   ┌───┬───┬───┐
   ▼   ▼   ▼   ▼
   1   2   3   4
```

Use for independent tasks. Limit: 4-5 parallel agents.

### Fan-Out/Fan-In

```
    Orchestrator
   ┌───┬───┬───┐
   ▼   ▼   ▼   ▼
   1   2   3   4
   └───┴───┴───┘
         ▼
    Aggregator
```

Use when results need integration.

## Best Practices

1. **Clear role definitions** - Each agent knows its scope
2. **Explicit handoffs** - STATUS signals with NEXT suggestions
3. **Persistent state** - Use work/ files, not just context
4. **Incremental commits** - Changes persist to git
5. **Observability** - Log all state transitions
6. **Graceful degradation** - Handle BLOCKED/ERROR states
7. **Context recovery** - Resume from work/ files after context reset

## References

- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Building agents with Claude Agent SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk)
- [How and when to build multi-agent systems](https://blog.langchain.com/how-and-when-to-build-multi-agent-systems/)
