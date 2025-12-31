---
description: Full BMAD cycle - review gaps, create epics, then implement in loop (requires claude-auto-agents plugin)
argument: project description or PRD reference
---

# /bmad-full - Complete BMAD Autonomous Cycle

Run the complete BMAD workflow: analyze requirements, identify gaps, create epics, validate readiness, then implement all epics in an autonomous loop.

## Usage

```
/bmad-full "implement user authentication system"
/bmad-full  # Continue from existing PRD/Architecture
```

## Requirements

- `claude-auto-agents` plugin for autonomous loop functionality
- Existing PRD and Architecture docs (or will create them)

## Workflow Phases

### Phase 1: Analysis & Gap Research
1. **Document Discovery** - Find existing PRD, Architecture, UX docs
2. **Gap Analysis** - Identify missing requirements, unclear specs
3. **Research** - Fill gaps through domain/technical research
4. **PRD Refinement** - Update PRD with findings

### Phase 2: Epic Creation Loop
1. **Validate Prerequisites** - Check PRD + Architecture completeness
2. **Design Epics** - Break requirements into logical epics
3. **Create Stories** - Write detailed user stories with acceptance criteria
4. **Readiness Check** - Validate epics cover all requirements
5. **Iterate** - If gaps found, return to step 1

### Phase 3: Implementation Loop
1. **Queue Epics** - Add all epics to work queue
2. **Start Loop** - Call `/bmad-loop` to implement
3. **Per Epic**:
   - Create feature branch
   - Implement with TDD
   - Code review
   - Create PR
   - Fix CI/review issues
   - Merge when approved
4. **Continue** - Until all epics complete

## Agent Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Phase 1: Analysis                        │
│  analyst → researcher → architect → pm (gap review)        │
│                         ↓                                   │
│                    [Gaps Found?]                            │
│                    ↙         ↘                              │
│                 [Yes]       [No]                            │
│                   ↓           ↓                             │
│              [Research]   [Continue]                        │
│                   ↓           ↓                             │
│              [Update PRD]     │                             │
│                   └───────────┘                             │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                  Phase 2: Epic Creation                     │
│  pm → analyst → architect → tea (validation)               │
│                         ↓                                   │
│              [Create Epics & Stories]                       │
│                         ↓                                   │
│              [Check Implementation Readiness]               │
│                         ↓                                   │
│                    [Ready?]                                 │
│                    ↙      ↘                                 │
│                 [No]      [Yes]                             │
│                   ↓         ↓                               │
│             [Fix Gaps]  [Continue]                          │
│                   └─────────┘                               │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                Phase 3: Implementation                      │
│  bmad-orchestrator → developer → reviewer → fixer          │
│                         ↓                                   │
│                  [/bmad-loop]                               │
│                         ↓                                   │
│              [Implement Each Epic]                          │
│                         ↓                                   │
│                    [Done]                                   │
└─────────────────────────────────────────────────────────────┘
```

## BMAD Workflows Used

### Analysis Phase
- `research/` - Domain, market, and technical research
- `create-product-brief/` - Initial product definition

### Planning Phase
- `prd/` - Product Requirements Document
- `create-architecture/` - System architecture
- `create-ux-design/` - UX specifications (if UI)

### Solutioning Phase
- `create-epics-and-stories/` - Epic and story creation
- `check-implementation-readiness/` - Validation before implementation

### Implementation Phase
- `/bmad-loop` - Autonomous epic implementation

## Output Structure

```
_bmad-output/
├── research/
│   ├── domain-research.md
│   ├── technical-research.md
│   └── gap-analysis.md
├── planning/
│   ├── product-brief.md
│   ├── prd.md
│   ├── architecture.md
│   └── ux-design.md
├── epics/
│   ├── epic-1A.md
│   ├── epic-2A.md
│   └── ...
├── stories/
│   ├── epic-1A/
│   │   ├── story-1.md
│   │   └── story-2.md
│   └── ...
└── readiness/
    └── implementation-readiness-report.md
```

## Monitoring

```bash
# Check current phase
/status

# View work queue
/queue list

# See gap analysis results
cat _bmad-output/research/gap-analysis.md

# Check readiness report
cat _bmad-output/readiness/implementation-readiness-report.md

# Stop at any point
/stop
```

## Configuration

Set iteration limits in `work/config.yaml`:

```yaml
bmad_full:
  max_gap_iterations: 5      # Max gap analysis cycles
  max_epic_iterations: 3     # Max epic refinement cycles
  require_readiness: true    # Must pass readiness check
  auto_implement: true       # Auto-start implementation
```

## Example

```bash
# Start full cycle for new feature
/bmad-full "implement multi-tenant support with role-based access control"

# This will:
# 1. Research multi-tenancy patterns and RBAC best practices
# 2. Create/update PRD with tenant isolation requirements
# 3. Design architecture for tenant separation
# 4. Create epics: tenant management, user roles, permission system
# 5. Validate all requirements are covered
# 6. Implement each epic with TDD, PR, review cycle
```

## STATUS Signal

```
STATUS: COMPLETE | BLOCKED | WAITING | ERROR
SUMMARY: Brief description of current phase and progress
FILES: comma-separated list of created/modified docs
NEXT: Next phase or action
BLOCKER: Reason if blocked (e.g., "Gap analysis found 3 unresolved issues")
```

## Autonomous Execution Instructions

You are the **bmad-orchestrator** running the full BMAD cycle. Follow these phases strictly:

### Phase 1: Analysis & Gap Research

**Step 1.1: Document Discovery**
```bash
# Find existing BMAD documents
ls -la _bmad-output/ 2>/dev/null || mkdir -p _bmad-output/{research,planning,epics,stories,readiness}
ls -la docs/*.md 2>/dev/null || true
```

Check for:
- `_bmad-output/planning/prd.md` - Product Requirements
- `_bmad-output/planning/architecture.md` - Architecture
- `_bmad-output/planning/ux-design.md` - UX (if UI)

**Step 1.2: Gap Analysis**
If documents exist, analyze for gaps:
- Missing requirements sections
- Unclear acceptance criteria
- Undefined edge cases
- Missing non-functional requirements

Create `_bmad-output/research/gap-analysis.md` with findings.

**Step 1.3: Research & Fill Gaps**
For each gap:
1. Research best practices
2. Document findings
3. Update PRD with new requirements

**Step 1.4: Phase 1 Complete Check**
Emit status:
```
STATUS: COMPLETE
SUMMARY: Phase 1 complete - analyzed docs, found N gaps, resolved M
FILES: _bmad-output/research/gap-analysis.md
NEXT: Phase 2 - Epic Creation
```

### Phase 2: Epic Creation Loop

**Step 2.1: Validate Prerequisites**
Ensure PRD and Architecture exist and are complete.

**Step 2.2: Create Epics**
Using BMAD workflow `create-epics-and-stories`:
1. Read PRD requirements
2. Group into logical epics
3. Write epic files to `_bmad-output/epics/`

**Step 2.3: Create Stories**
For each epic:
1. Break into user stories
2. Write acceptance criteria
3. Save to `_bmad-output/stories/epic-{id}/`

**Step 2.4: Readiness Check**
Run `check-implementation-readiness` workflow:
- Verify all requirements covered
- Check story quality
- Validate dependencies

If NOT ready:
```
STATUS: BLOCKED
SUMMARY: Implementation readiness check failed
BLOCKER: [List of issues from readiness report]
NEXT: Fix gaps and re-run Phase 2
```

If ready:
```
STATUS: COMPLETE
SUMMARY: Phase 2 complete - created N epics with M stories
FILES: _bmad-output/epics/, _bmad-output/stories/
NEXT: Phase 3 - Implementation Loop
```

### Phase 3: Implementation Loop

**Step 3.1: Queue All Epics**
Add each epic to `work/queue.md`:
```markdown
## Pending
- [ ] **[EPIC-1A]** Implement epic 1A: {title}
  - Priority: high
  - Agent: bmad-orchestrator
- [ ] **[EPIC-2A]** Implement epic 2A: {title}
  - Priority: high
  - Agent: bmad-orchestrator
```

**Step 3.2: Start Implementation Loop**
The loop will process each epic:
1. Create feature branch
2. Implement with TDD
3. Code review
4. Create PR
5. Fix CI/review issues
6. Merge when approved

**Step 3.3: Per-Epic Completion**
After each epic:
```
STATUS: COMPLETE
SUMMARY: Implemented epic {id}: {title}
FILES: [changed files]
NEXT: Process next epic {next_id} or "All epics complete"
```

### Phase Tracking

Track current phase in `work/current.md`:
```markdown
# Current Work

## Phase: [1-Analysis | 2-Epics | 3-Implementation]
## Status: [In Progress | Blocked | Complete]
## Current Task: [description]
## Iteration: [N]
```

### Error Recovery

If any phase fails:
1. Log error to `work/blockers.md`
2. Emit STATUS: ERROR with details
3. The loop will pause for manual intervention

### Completion

When all phases complete:
```
STATUS: COMPLETE
SUMMARY: Full BMAD cycle complete - implemented N epics
FILES: [all changed files]
NEXT: All work complete. Review PRs and deployed features.
```
