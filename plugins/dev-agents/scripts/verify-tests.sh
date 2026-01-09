#!/usr/bin/env bash
# Run tests and verify results
# Detects project type and runs appropriate test command
# Usage: verify-tests.sh [--coverage]

set -euo pipefail

COVERAGE="${1:-}"

# Detect project type and run tests
run_tests() {
    # Node.js / npm
    if [[ -f "package.json" ]]; then
        if grep -q '"test"' package.json 2>/dev/null; then
            echo "Running npm test..."
            if [[ "$COVERAGE" == "--coverage" ]]; then
                npm test -- --coverage 2>&1
            else
                npm test 2>&1
            fi
            return $?
        fi
    fi

    # Python
    if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -d "tests" ]]; then
        if command -v pytest &> /dev/null; then
            echo "Running pytest..."
            if [[ "$COVERAGE" == "--coverage" ]]; then
                pytest --cov 2>&1
            else
                pytest 2>&1
            fi
            return $?
        fi
    fi

    # Rust
    if [[ -f "Cargo.toml" ]]; then
        echo "Running cargo test..."
        cargo test 2>&1
        return $?
    fi

    # Go
    if [[ -f "go.mod" ]]; then
        echo "Running go test..."
        if [[ "$COVERAGE" == "--coverage" ]]; then
            go test -cover ./... 2>&1
        else
            go test ./... 2>&1
        fi
        return $?
    fi

    # Makefile with test target
    if [[ -f "Makefile" ]] && grep -q '^test:' Makefile 2>/dev/null; then
        echo "Running make test..."
        make test 2>&1
        return $?
    fi

    echo "TEST_RESULT=skip"
    echo "MESSAGE=No test framework detected"
    return 0
}

# Run tests and capture result
OUTPUT=$(run_tests)
EXIT_CODE=$?

# Parse output for test results
echo "$OUTPUT"

if [[ $EXIT_CODE -eq 0 ]]; then
    echo ""
    echo "TEST_RESULT=success"
    echo "EXIT_CODE=0"
else
    echo ""
    echo "TEST_RESULT=failure"
    echo "EXIT_CODE=$EXIT_CODE"
fi

exit $EXIT_CODE
