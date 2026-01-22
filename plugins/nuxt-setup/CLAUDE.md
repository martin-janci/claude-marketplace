# Nuxt Setup

Nuxt/Vue/TypeScript project setup toolkit - from fresh clone to working LSP.

## Skills

| Skill | Description |
|-------|-------------|
| **nuxt-setup/** | Complete setup workflow - deps, Nuxt prepare, LSP, TypeScript |

## When to Use

- Fresh clone of a Nuxt project
- After creating a new worktree
- TypeScript errors after config changes
- LSP not recognizing auto-imports
- Setting up editor for Nuxt development

## Quick Reference

```bash
# Full setup
yarn install
npx nuxt prepare
npx vue-tsc --noEmit

# Regenerate types
rm -rf .nuxt
npx nuxt prepare

# Package manager detection
# yarn.lock → yarn
# package-lock.json → npm
# pnpm-lock.yaml → pnpm
```

## Integration

Works with **worktree** plugin - run nuxt-setup after creating a worktree to prepare the isolated environment.
