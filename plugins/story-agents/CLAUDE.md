# Story Agents

Feature and story development agents for implementing epics, stories, and fixing issues.

## Agents

| Agent | Description |
|-------|-------------|
| `story-developer` | Epic and story implementation |
| `issue-fixer` | Issue resolution specialist |
| `explorer` | Code exploration and analysis |
| `test-writer` | Test implementation specialist |

## Skills

- **executing-plans/** - Plan execution workflow
- **sharing-skills/** - Skill sharing patterns

## Commands

- `/stories-parallel` - Run 2-4 stories in parallel using git worktrees

## Usage

Spawn agents for feature development:
```
/spawn story-developer "implement STORY-123: user profile page"
/spawn issue-fixer "fix BUG-456: login timeout"
/spawn explorer "understand the authentication flow"
/spawn test-writer "add tests for the payment module"
```

Run multiple stories in parallel:
```
/stories-parallel "STORY-1: Add login" "STORY-2: Add logout" "STORY-3: Add profile"
```
