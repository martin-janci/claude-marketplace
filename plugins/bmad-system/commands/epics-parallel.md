---
description: Run 2-4 epics in parallel using git worktrees for isolation
argument: epic IDs or patterns (space-separated, max 4)
---

# /epics-parallel - Parallel Epic Implementation

Implement multiple BMAD epics simultaneously using isolated git worktrees and parallel Task agents.

## Usage

```
/epics-parallel "7A" "8A" "9A"
/epics-parallel "epic-1A" "epic-2A" "epic-3A" "epic-4A"
```

## Requirements

- Git repository with clean working tree
- `dev-agents` plugin for `using-git-worktrees` skill
- `claude-auto-agents` plugin for Task spawning
- Epics defined in `_bmad-output/epics/`

## Behavior

1. Validates epic files exist in `_bmad-output/epics/`
2. Creates isolated git worktree for each epic
3. Spawns `bmad-orchestrator` agent in each worktree (via Task tool)
4. Each agent implements all stories in their epic with TDD
5. Agents emit STATUS signals on completion
6. Results merged back via PRs

## Limits

- **Maximum 4 parallel epics** - prevents resource exhaustion
- **Minimum 2 epics** - use `/bmad-loop` for single epic

## Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    /epics-parallel                           │
│                                                              │
│   1. Validate epic files exist (2-4 epics)                  │
│   2. Create worktrees for each epic                         │
│   3. Spawn parallel bmad-orchestrator agents                │
│   4. Monitor STATUS signals                                  │
│   5. Merge completed branches via PRs                        │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  Worktree 1   │    │  Worktree 2   │    │  Worktree 3   │
│  epic-7A      │    │  epic-8A      │    │  epic-9A      │
│  (branch)     │    │  (branch)     │    │  (branch)     │
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ bmad-orch     │    │ bmad-orch     │    │ bmad-orch     │
│ - stories     │    │ - stories     │    │ - stories     │
│ - TDD         │    │ - TDD         │    │ - TDD         │
│ - tests       │    │ - tests       │    │ - tests       │
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
   STATUS:COMPLETE      STATUS:COMPLETE      STATUS:COMPLETE
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
                    ┌─────────────────┐
                    │  Create PRs     │
                    │  Review & Merge │
                    └─────────────────┘
```

## Epic Discovery

Epics are found in:
- `_bmad-output/epics/*.md`

Each epic file should contain:
- Epic title and description
- List of stories with acceptance criteria
- Dependencies (if any)

## Git Worktree Setup

For each epic, the orchestrator will:

```bash
# Create worktree directory
mkdir -p .worktrees

# Ensure .gitignore has worktrees
grep -q "^\.worktrees/$" .gitignore || echo ".worktrees/" >> .gitignore

# Create worktree with new branch
git worktree add ".worktrees/epic-${EPIC_ID}" -b "feature/epic-${EPIC_ID}"
```

## Agent Spawning

Each epic gets a `bmad-orchestrator` agent via Task tool:

```
Task(
  subagent_type: "developer",
  prompt: "Implement epic ${EPIC_ID} in worktree .worktrees/epic-${EPIC_ID}.
           Read epic file from _bmad-output/epics/${EPIC_ID}.md.
           Implement all stories with TDD.
           Create PR when done. Emit STATUS signal.",
  run_in_background: true
)
```

## Monitoring

```bash
# Check worktree status
git worktree list

# Check agent status
/status

# View individual epic progress
cat .worktrees/epic-*/work/current.md

# List all PRs
gh pr list
```

## Completion

When all agents emit `STATUS: COMPLETE`:

1. Each creates a PR from their feature branch
2. PRs can be reviewed and merged independently
3. Worktrees are cleaned up after merge

```bash
# Cleanup after merge
git worktree remove .worktrees/epic-${EPIC_ID}
git branch -d feature/epic-${EPIC_ID}
```

## Example

```bash
# Start 3 epics in parallel
/epics-parallel "7A" "8A" "9A"

# This will:
# 1. Verify _bmad-output/epics/7A.md, 8A.md, 9A.md exist
# 2. Create .worktrees/epic-7A, .worktrees/epic-8A, .worktrees/epic-9A
# 3. Spawn 3 bmad-orchestrator agents (background)
# 4. Each implements their epic's stories with TDD
# 5. Each creates a PR
# 6. You review and merge PRs
```

## STATUS Signal

```
STATUS: COMPLETE | BLOCKED | WAITING | ERROR
SUMMARY: Brief description of parallel execution status
FILES: List of worktrees created
NEXT: Review PRs or resolve blockers
BLOCKER: Reason if any epic is blocked
```

## Autonomous Execution Instructions

You are the **parallel-epic-orchestrator**. Execute these steps:

### Step 1: Validate Input

```bash
# Count epics (must be 2-4)
EPIC_COUNT=$#
if [[ $EPIC_COUNT -lt 2 ]] || [[ $EPIC_COUNT -gt 4 ]]; then
    echo "ERROR: Must provide 2-4 epics. Got: $EPIC_COUNT"
    exit 1
fi

# Verify epic files exist
for epic_id in "$@"; do
    EPIC_FILE="_bmad-output/epics/${epic_id}.md"
    if [[ ! -f "$EPIC_FILE" ]]; then
        echo "ERROR: Epic file not found: $EPIC_FILE"
        exit 1
    fi
done
```

### Step 2: Setup Worktrees

```bash
# Ensure clean git state
git status --porcelain | grep -q . && echo "ERROR: Working tree not clean" && exit 1

# Create worktree directory
mkdir -p .worktrees

# Add to gitignore if needed
grep -q "^\.worktrees/$" .gitignore 2>/dev/null || echo ".worktrees/" >> .gitignore

# Create worktree for each epic
for epic_id in "$@"; do
    git worktree add ".worktrees/epic-${epic_id}" -b "feature/epic-${epic_id}"
done
```

### Step 3: Spawn Parallel Agents

Use the Task tool to spawn `bmad-orchestrator` agents in parallel.

For each epic, spawn a Task with:
- `subagent_type`: "developer"
- `run_in_background`: true
- `prompt`: Include epic ID, worktree path, epic file location, TDD instructions

**IMPORTANT**: Spawn all agents in a SINGLE message with multiple Task tool calls for true parallelism.

Example prompt for each agent:
```
You are implementing epic ${EPIC_ID} in an isolated git worktree.

Working directory: .worktrees/epic-${EPIC_ID}
Epic file: _bmad-output/epics/${EPIC_ID}.md

Instructions:
1. cd to the worktree: cd .worktrees/epic-${EPIC_ID}
2. Read the epic file to understand requirements
3. For each story in the epic:
   - Write tests first (TDD)
   - Implement the feature
   - Ensure tests pass
4. When all stories complete, create PR:
   gh pr create --title "Epic ${EPIC_ID}: [title]" --body "[description]"
5. Emit STATUS signal

STATUS: COMPLETE
SUMMARY: Implemented epic ${EPIC_ID} with N stories
FILES: [changed files]
NEXT: Review PR for epic ${EPIC_ID}
```

### Step 4: Monitor and Report

After spawning all agents:

```
STATUS: WAITING
SUMMARY: Spawned N bmad-orchestrator agents for epics: ${EPIC_IDS}
FILES: .worktrees/epic-7A, .worktrees/epic-8A, ...
NEXT: Monitor agent completion, then review PRs
```

### Step 5: Completion Check

When checking status later:
- If all agents complete: `STATUS: COMPLETE`
- If any blocked: `STATUS: BLOCKED` with details
- If any error: `STATUS: ERROR` with details

### Cleanup After Merge

After PRs are merged:

```bash
# Remove worktrees
for epic_id in "$@"; do
    git worktree remove ".worktrees/epic-${epic_id}"
    git branch -d "feature/epic-${epic_id}"
done
```
