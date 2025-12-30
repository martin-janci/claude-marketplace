---
description: Launch a specific agent type
argument: agent-type task-description
---

# /spawn - Launch Agent

Spawn a specific type of agent to handle a task.

## Usage

```
/spawn developer "implement user authentication"
/spawn reviewer   # Review current changes
/spawn fixer "fix failing test in auth.test.ts"
/spawn explorer "find where database connections are created"
```

## Available Agents

| Agent | Tools | Model | Use Case |
|-------|-------|-------|----------|
| `developer` | All + Task | sonnet | Feature implementation |
| `reviewer` | Read-only | sonnet | Code review |
| `fixer` | All | sonnet | Fix issues/failures |
| `orchestrator` | All + Task | opus | Autonomous control |
| `explorer` | Read-only | haiku | Codebase exploration |
| `pr-shepherd` | All + Task | sonnet | PR management |
| `conflict-resolver` | All | sonnet | Merge conflicts |

## Examples

### Develop a Feature
```
/spawn developer "add password reset functionality with email verification"
```

### Review Changes
```
/spawn reviewer "review the authentication changes"
```

### Fix a Bug
```
/spawn fixer "fix the race condition in user session handling"
```

### Explore Codebase
```
/spawn explorer "map the database schema and relationships"
```

### Manage PR
```
/spawn pr-shepherd "create PR for current branch and monitor CI"
```

## Behavior

1. Task tool is invoked with specified agent type
2. Agent receives task description
3. Agent works until STATUS signal emitted
4. Control returns with agent output

## Notes

- Agents are specialized with different capabilities
- Use `developer` for new features
- Use `fixer` for bugs and failures
- Use `explorer` for read-only analysis
- Orchestrator manages the full workflow
