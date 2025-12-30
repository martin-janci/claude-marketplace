---
description: Auto-invoke for code review tasks
triggers:
  - "review"
  - "check code"
  - "audit"
---

# Review Skill

Automatically invoked for code review tasks.

## Trigger Patterns

This skill activates when detecting:
- "review [changes]"
- "check code [for X]"
- "audit [component]"
- "look at [PR/changes]"

## Behavior

1. Spawn `reviewer` agent
2. Agent analyzes code read-only
3. Checks quality, security, patterns
4. Provides structured feedback
5. Emits verdict: APPROVED or CHANGES_REQUESTED

## Example Triggers

```
"review the authentication changes"
→ Spawns reviewer for recent changes

"check code for security issues"
→ Spawns reviewer with security focus

"audit the database module"
→ Spawns reviewer for specific area
```

## Agent Selection

Uses the `reviewer` agent which has:
- Read-only tools (Bash, Read, Glob, Grep)
- Sonnet model
- 30 turn limit
- Structured review output

## Output

Reviewer agent will:
1. Read changed files
2. Check against quality criteria
3. Identify issues by severity
4. Provide verdict and suggestions
5. Emit STATUS: COMPLETE with review summary

## Review Criteria

- Code quality and patterns
- Security vulnerabilities
- Test coverage
- Architecture alignment
- Documentation
