#!/usr/bin/env bash
# Auto-lint modified files in the current git repository
# Detects project type and runs appropriate linter
# Usage: lint-changes.sh [--staged|--all]

set -euo pipefail

MODE="${1:---staged}"

# Get list of files to lint as array
case "$MODE" in
    --staged)
        mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
        ;;
    --all)
        mapfile -t FILES < <(git diff --name-only HEAD 2>/dev/null || true)
        ;;
    *)
        echo "Usage: lint-changes.sh [--staged|--all]"
        exit 1
        ;;
esac

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "LINT_RESULT=skip"
    echo "MESSAGE=No files to lint"
    exit 0
fi

ERRORS=0
LINTED=0

# Filter files by extension into arrays
mapfile -t TS_FILES < <(printf '%s\n' "${FILES[@]}" | grep -E '\.(ts|tsx|js|jsx)$' || true)
mapfile -t PY_FILES < <(printf '%s\n' "${FILES[@]}" | grep -E '\.py$' || true)
mapfile -t RS_FILES < <(printf '%s\n' "${FILES[@]}" | grep -E '\.rs$' || true)
mapfile -t GO_FILES < <(printf '%s\n' "${FILES[@]}" | grep -E '\.go$' || true)
mapfile -t SH_FILES < <(printf '%s\n' "${FILES[@]}" | grep -E '\.(sh|bash)$' || true)

# TypeScript/JavaScript
if [[ ${#TS_FILES[@]} -gt 0 ]]; then
    if [[ -f "package.json" ]]; then
        if grep -q '"eslint"' package.json 2>/dev/null; then
            echo "Running ESLint on TypeScript/JavaScript files..."
            if npx eslint --fix "${TS_FILES[@]}" 2>/dev/null; then
                ((LINTED++))
            else
                ((ERRORS++))
            fi
        elif grep -q '"biome"' package.json 2>/dev/null; then
            echo "Running Biome on TypeScript/JavaScript files..."
            if npx biome check --apply "${TS_FILES[@]}" 2>/dev/null; then
                ((LINTED++))
            else
                ((ERRORS++))
            fi
        fi
    fi
fi

# Python
if [[ ${#PY_FILES[@]} -gt 0 ]]; then
    if command -v ruff &> /dev/null; then
        echo "Running Ruff on Python files..."
        if ruff check --fix "${PY_FILES[@]}" 2>/dev/null; then
            ((LINTED++))
        else
            ((ERRORS++))
        fi
    elif command -v black &> /dev/null; then
        echo "Running Black on Python files..."
        if black "${PY_FILES[@]}" 2>/dev/null; then
            ((LINTED++))
        else
            ((ERRORS++))
        fi
    fi
fi

# Rust
if [[ ${#RS_FILES[@]} -gt 0 ]]; then
    if command -v cargo &> /dev/null && [[ -f "Cargo.toml" ]]; then
        echo "Running cargo fmt..."
        if cargo fmt 2>/dev/null; then
            ((LINTED++))
        else
            ((ERRORS++))
        fi
    fi
fi

# Go
if [[ ${#GO_FILES[@]} -gt 0 ]]; then
    if command -v gofmt &> /dev/null; then
        echo "Running gofmt..."
        if gofmt -w "${GO_FILES[@]}" 2>/dev/null; then
            ((LINTED++))
        else
            ((ERRORS++))
        fi
    fi
fi

# Shell scripts
if [[ ${#SH_FILES[@]} -gt 0 ]]; then
    if command -v shellcheck &> /dev/null; then
        echo "Running shellcheck..."
        if shellcheck "${SH_FILES[@]}" 2>/dev/null; then
            ((LINTED++))
        else
            ((ERRORS++))
        fi
    fi
fi

# Output results
if [[ $ERRORS -gt 0 ]]; then
    echo "LINT_RESULT=error"
    echo "ERRORS=$ERRORS"
    echo "LINTED=$LINTED"
    exit 1
elif [[ $LINTED -gt 0 ]]; then
    echo "LINT_RESULT=success"
    echo "LINTED=$LINTED"
    exit 0
else
    echo "LINT_RESULT=skip"
    echo "MESSAGE=No applicable linters found"
    exit 0
fi
