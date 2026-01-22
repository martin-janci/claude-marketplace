# Worktree

Git worktree management for parallel branch development.

## Skills

| Skill | Description |
|-------|-------------|
| **worktree/** | Create, list, delete, switch worktrees |

## When to Use

- Starting feature work that needs isolation
- Working on multiple branches simultaneously
- Need separate dev servers for different features
- Code review while continuing development
- Experimental work without affecting main workspace

## Quick Reference

```bash
# Create worktree with new branch
git worktree add .worktrees/<name> -b <branch>

# List all worktrees
git worktree list

# Remove worktree
git worktree remove .worktrees/<name>

# Clean up stale references
git worktree prune
```

## Recommended Structure

```
project/
├── .worktrees/           # All worktrees here
│   ├── feature-auth/
│   └── bugfix-login/
├── .gitignore            # Must include .worktrees/
└── ...
```

## Integration

Works with **nuxt-setup** plugin - after creating worktree, run nuxt-setup to install deps and prepare types.
