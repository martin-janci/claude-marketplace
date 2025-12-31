---
description: Run 2-4 stories in parallel using git worktrees for isolation
argument: story IDs or descriptions (space-separated, max 4)
---

# /stories-parallel - Parallel Story Implementation

Implement multiple stories simultaneously using isolated git worktrees and parallel Task agents.

## Usage

```
/stories-parallel "STORY-1" "STORY-2" "STORY-3"
/stories-parallel "add login page" "add logout button" "add password reset"
```

## Requirements

- Git repository with clean working tree
- `dev-agents` plugin for `using-git-worktrees` skill
- `claude-auto-agents` plugin for Task spawning

## Behavior

1. Creates isolated git worktree for each story
2. Spawns `story-developer` agent in each worktree (via Task tool)
3. Each agent works independently with TDD
4. Agents emit STATUS signals on completion
5. Results are merged back to main branch

## Limits

- **Maximum 4 parallel stories** - prevents resource exhaustion
- **Minimum 2 stories** - use regular `/spawn story-developer` for single story

## Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    /stories-parallel                         │
│                                                              │
│   1. Validate inputs (2-4 stories)                          │
│   2. Create worktrees for each story                        │
│   3. Spawn parallel Task agents                             │
│   4. Monitor STATUS signals                                  │
│   5. Merge completed branches                                │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  Worktree 1   │    │  Worktree 2   │    │  Worktree 3   │
│  story-dev    │    │  story-dev    │    │  story-dev    │
│  (branch A)   │    │  (branch B)   │    │  (branch C)   │
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
   STATUS:COMPLETE      STATUS:COMPLETE      STATUS:COMPLETE
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
                    ┌─────────────────┐
                    │  Merge all PRs  │
                    └─────────────────┘
```

## Git Worktree Setup

For each story, the orchestrator will:

```bash
# Create worktree directory
mkdir -p .worktrees

# Ensure .gitignore has worktrees
grep -q "^\.worktrees/$" .gitignore || echo ".worktrees/" >> .gitignore

# Create worktree with new branch
git worktree add ".worktrees/story-${STORY_ID}" -b "feature/story-${STORY_ID}"
```

## Agent Spawning

Each story gets a `story-developer` agent via Task tool:

```
Task(
  subagent_type: "developer",
  prompt: "Implement story in worktree .worktrees/story-${STORY_ID}.
           Use TDD. Create PR when done. Emit STATUS signal.",
  run_in_background: true
)
```

## Monitoring

```bash
# Check worktree status
git worktree list

# Check agent status
/status

# View individual story progress
cat .worktrees/story-*/work/current.md
```

## Completion

When all agents emit `STATUS: COMPLETE`:

1. Each creates a PR from their feature branch
2. PRs can be reviewed and merged independently
3. Worktrees are cleaned up after merge

```bash
# Cleanup after merge
git worktree remove .worktrees/story-${STORY_ID}
git branch -d feature/story-${STORY_ID}
```

## Example

```bash
# Start 3 stories in parallel
/stories-parallel "STORY-101: Add user profile page" "STORY-102: Add settings page" "STORY-103: Add notification preferences"

# This will:
# 1. Create .worktrees/story-101, .worktrees/story-102, .worktrees/story-103
# 2. Spawn 3 story-developer agents (background)
# 3. Each implements their story with TDD
# 4. Each creates a PR
# 5. You review and merge PRs
```

## STATUS Signal

```
STATUS: COMPLETE | BLOCKED | WAITING | ERROR
SUMMARY: Brief description of parallel execution status
FILES: List of worktrees created
NEXT: Review PRs or resolve blockers
BLOCKER: Reason if any story is blocked
```

## Autonomous Execution Instructions

You are the **parallel-story-orchestrator**. Execute these steps:

### Step 1: Validate Input

```bash
# Count stories (must be 2-4)
STORY_COUNT=$#
if [[ $STORY_COUNT -lt 2 ]] || [[ $STORY_COUNT -gt 4 ]]; then
    echo "ERROR: Must provide 2-4 stories. Got: $STORY_COUNT"
    exit 1
fi
```

### Step 2: Setup Worktrees

```bash
# Ensure clean git state
git status --porcelain | grep -q . && echo "ERROR: Working tree not clean" && exit 1

# Create worktree directory
mkdir -p .worktrees

# Add to gitignore if needed
grep -q "^\.worktrees/$" .gitignore 2>/dev/null || echo ".worktrees/" >> .gitignore

# Create worktree for each story
for story in "$@"; do
    STORY_ID=$(echo "$story" | sed 's/[^a-zA-Z0-9]/-/g' | cut -c1-30)
    git worktree add ".worktrees/$STORY_ID" -b "feature/$STORY_ID"
done
```

### Step 3: Spawn Parallel Agents

Use the Task tool to spawn `story-developer` agents in parallel:

For each story, spawn a Task with:
- `subagent_type`: "developer"
- `run_in_background`: true
- `prompt`: Include story details, worktree path, TDD instructions

### Step 4: Monitor and Report

After spawning all agents:

```
STATUS: WAITING
SUMMARY: Spawned N story-developer agents in parallel worktrees
FILES: .worktrees/story-1, .worktrees/story-2, ...
NEXT: Monitor agent completion, then review PRs
```

### Step 5: Completion Check

When checking status later:
- If all agents complete: `STATUS: COMPLETE`
- If any blocked: `STATUS: BLOCKED` with details
- If any error: `STATUS: ERROR` with details
