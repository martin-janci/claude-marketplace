---
description: Auto-invoke for feature development tasks
triggers:
  - "implement"
  - "add feature"
  - "create"
  - "build"
---

# Develop Skill

Automatically invoked for feature development tasks.

## Trigger Patterns

This skill activates when detecting:
- "implement [feature]"
- "add [functionality]"
- "create [component]"
- "build [feature]"

## Behavior

1. Spawn `developer` agent
2. Agent follows TDD methodology
3. Creates tests first, then implementation
4. Emits STATUS signal on completion

## Example Triggers

```
"implement user authentication"
→ Spawns developer with auth task

"add a dark mode toggle"
→ Spawns developer with UI task

"create an API endpoint for users"
→ Spawns developer with API task
```

## Agent Selection

Uses the `developer` agent which has:
- Full tool access (Bash, Read, Write, Edit, Glob, Grep, Task)
- Sonnet model
- 80 turn limit
- TDD workflow

## Output

Developer agent will:
1. Analyze requirements
2. Write failing tests
3. Implement code to pass tests
4. Refactor if needed
5. Emit STATUS: COMPLETE with summary
