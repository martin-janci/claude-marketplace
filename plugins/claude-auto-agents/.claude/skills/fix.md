---
description: Auto-invoke for fixing issues and failures
triggers:
  - "fix"
  - "debug"
  - "resolve"
  - "failing"
  - "broken"
---

# Fix Skill

Automatically invoked for fixing issues, failures, and bugs.

## Trigger Patterns

This skill activates when detecting:
- "fix [issue]"
- "debug [problem]"
- "resolve [error]"
- "tests are failing"
- "broken [component]"

## Behavior

1. Spawn `fixer` agent
2. Agent diagnoses the issue
3. Implements minimal fix
4. Verifies fix works
5. Emits STATUS signal

## Example Triggers

```
"fix the failing tests in auth.test.ts"
→ Spawns fixer for specific test file

"debug the login race condition"
→ Spawns fixer for runtime issue

"resolve the CI build error"
→ Spawns fixer for CI failure

"the API endpoint is broken"
→ Spawns fixer to investigate
```

## Agent Selection

Uses the `fixer` agent which has:
- Full tool access (Bash, Read, Write, Edit, Glob, Grep)
- Sonnet model
- 40 turn limit
- Minimal change philosophy

## Output

Fixer agent will:
1. Understand the error/failure
2. Locate the root cause
3. Implement minimal fix
4. Verify the fix works
5. Emit STATUS: COMPLETE or BLOCKED

## Fix Philosophy

- Minimal changes only
- Fix root cause, not symptoms
- Run tests to verify
- Document non-obvious fixes
- Don't refactor while fixing
