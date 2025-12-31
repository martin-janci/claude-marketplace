---
description: Run BMAD epics in autonomous loop (requires claude-auto-agents plugin)
argument: epic pattern to process (e.g., "7A", "7A 8A", "10.*")
---

# /bmad-loop - Run BMAD Epics in Autonomous Loop

Process BMAD epics continuously using the autonomous loop from claude-auto-agents plugin.

## Usage

```
/bmad-loop [epic-pattern]
/bmad-loop "7A 8A 10B"
/bmad-loop "sprint-12.*"
```

## Requirements

This command requires the `claude-auto-agents` plugin to be installed for autonomous loop functionality.

## Behavior

1. Scans for BMAD epic files matching the pattern
2. Adds each epic as a work item to `work/queue.md`
3. Starts the autonomous loop
4. For each epic:
   - Creates feature branch
   - Implements stories with TDD
   - Runs code review
   - Creates PR
   - Monitors CI and fixes issues
   - Merges when approved
5. Continues to next epic until queue empty

## Epic Discovery

Epics are found in:
- `_bmad-output/epics/`
- `_bmad-output/stories/epic-*/`
- `docs/epics/`

## Work Queue Format

Each epic is added to the queue as:
```markdown
- [ ] **[EPIC-{id}]** Implement epic {id}: {title}
  - Priority: high
  - Agent: bmad-orchestrator
```

## Monitoring

```bash
# Check loop status
/status

# View queue
/queue list

# Stop the loop
/stop
```

## Example

```
# Process all epics in sprint 12
/bmad-loop "sprint-12.*"

# Process specific epics
/bmad-loop "7A 8A"

# Process all available epics
/bmad-loop
```

## STATUS Signal

```
STATUS: COMPLETE | BLOCKED | WAITING | ERROR
SUMMARY: Brief description of epic processing status
FILES: comma-separated list of changed files
NEXT: Next epic to process or completion message
BLOCKER: Reason if blocked (e.g., CI failure, review required)
```

## Autonomous Execution

When invoked, this command will:

1. **Discover Epics**: Search for epic files matching the pattern
2. **Queue Epics**: Add each epic to `work/queue.md` with proper format
3. **Start Loop**: Activate the autonomous loop via loop-control
4. **Orchestrate**: The bmad-orchestrator agent handles each epic

### Step 1: Discover and Queue Epics

First, find epic files and add them to the work queue:

```bash
# Find epic files
PATTERN="${ARGUMENTS:-*}"
EPIC_DIR="_bmad-output/epics"

# Initialize work directory if needed
mkdir -p work

# Find matching epics and queue them
for epic_file in "$EPIC_DIR"/*.md; do
    if [[ -f "$epic_file" ]]; then
        epic_id=$(basename "$epic_file" .md)
        epic_title=$(head -1 "$epic_file" | sed 's/^#* *//')

        # Add to queue if matches pattern
        if [[ "$epic_id" == *"$PATTERN"* ]] || [[ "$PATTERN" == "*" ]]; then
            echo "- [ ] **[EPIC-$epic_id]** Implement: $epic_title" >> work/queue.md
            echo "  - Priority: high" >> work/queue.md
            echo "  - Agent: bmad-orchestrator" >> work/queue.md
        fi
    fi
done
```

### Step 2: Activate the Loop

The loop will be started automatically. Epic pattern: `$ARGUMENTS`

After discovering epics, the orchestrator will:
1. Read the epic file to understand requirements
2. Create a feature branch
3. Implement each story with TDD
4. Request code review
5. Create PR and monitor CI
6. Fix any issues
7. Merge when approved
8. Emit STATUS: COMPLETE and move to next epic

### Agent Instructions

You are the **bmad-orchestrator**. For each epic in the queue:

1. **Read the epic file** from `_bmad-output/epics/` or `_bmad-output/stories/`
2. **Create feature branch**: `git checkout -b feature/epic-{id}`
3. **For each story in the epic**:
   - Write tests first (TDD)
   - Implement the feature
   - Ensure tests pass
4. **Request review**: Use the reviewer agent or `/spawn reviewer`
5. **Create PR**: `gh pr create --title "Epic {id}: {title}"`
6. **Monitor CI**: Wait for checks, fix if needed
7. **Merge**: When approved and CI passes
8. **Emit STATUS**:
   ```
   STATUS: COMPLETE
   SUMMARY: Implemented epic {id}: {title}
   FILES: list of changed files
   NEXT: Process next epic or "All epics complete"
   ```

If blocked:
```
STATUS: BLOCKED
SUMMARY: Cannot proceed with epic {id}
BLOCKER: Specific reason (e.g., "CI failing on test X", "Needs architecture decision")
```
