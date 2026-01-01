#!/bin/bash
# status-parser.sh - Parse and manage STATUS signals
#
# Provides:
# - Parse STATUS from text (parse_status)
# - File-based STATUS read/write (write_status, read_status, clear_status)
# - Validation utilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh" 2>/dev/null || true

# Status file location
STATUS_FILE="$(get_work_dir 2>/dev/null || echo "$SCRIPT_DIR")/.status"
STATUS_MAX_AGE=300  # 5 minutes

# === Text-based parsing ===

# Parse STATUS signal from text
# Usage: parse_status "text with STATUS: COMPLETE etc"
# Outputs shell-sourceable variables
parse_status() {
    local text="$1"

    # Extract each field
    local status summary files next blocker
    status=$(echo "$text" | grep -E "^STATUS:" | head -1 | cut -d: -f2 | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    summary=$(echo "$text" | grep -E "^SUMMARY:" | head -1 | cut -d: -f2- | sed 's/^ *//')
    files=$(echo "$text" | grep -E "^FILES:" | head -1 | cut -d: -f2- | sed 's/^ *//')
    next=$(echo "$text" | grep -E "^NEXT:" | head -1 | cut -d: -f2- | sed 's/^ *//')
    blocker=$(echo "$text" | grep -E "^BLOCKER:" | head -1 | cut -d: -f2- | sed 's/^ *//')

    # Output as shell-sourceable format
    echo "STATUS_VALUE=\"$status\""
    echo "STATUS_SUMMARY=\"$summary\""
    echo "STATUS_FILES=\"$files\""
    echo "STATUS_NEXT=\"$next\""
    echo "STATUS_BLOCKER=\"$blocker\""
}

# Check if text contains a valid STATUS signal
has_status() {
    local text="$1"
    echo "$text" | grep -qE "^STATUS:\s*(COMPLETE|BLOCKED|WAITING|ERROR)"
}

# Get just the status value (COMPLETE, BLOCKED, etc)
get_status_value() {
    local text="$1"
    echo "$text" | grep -E "^STATUS:" | head -1 | cut -d: -f2 | tr -d ' ' | tr '[:lower:]' '[:upper:]'
}

# Validate status value
is_valid_status() {
    local status="$1"
    case "$status" in
        COMPLETE|BLOCKED|WAITING|ERROR)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# === File-based STATUS operations ===

# Write STATUS to file (agents call this)
# Usage: write_status "COMPLETE" "Summary text" "file1.ts,file2.ts" "Next action" "Blocker reason"
write_status() {
    local status="$1"
    local summary="$2"
    local files="${3:-}"
    local next="${4:-}"
    local blocker="${5:-}"

    local work_dir
    work_dir="$(get_work_dir 2>/dev/null || echo "$SCRIPT_DIR")"
    local status_file="$work_dir/.status"

    mkdir -p "$work_dir"

    cat > "$status_file" << EOF
TIMESTAMP: $(get_timestamp 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
STATUS: $status
SUMMARY: $summary
FILES: $files
NEXT: $next
BLOCKER: $blocker
EOF

    log_debug "STATUS written: $status - $summary" 2>/dev/null || true
}

# Read STATUS from file
# Returns shell-sourceable variables including STATUS_VALID and STATUS_STALE
read_status() {
    local status_file="${1:-$STATUS_FILE}"

    # Default output for missing/invalid file
    if [[ ! -f "$status_file" ]]; then
        echo "STATUS_VALID=false"
        echo "STATUS_STALE=true"
        echo "STATUS_VALUE=\"\""
        echo "STATUS_SUMMARY=\"\""
        echo "STATUS_FILES=\"\""
        echo "STATUS_NEXT=\"\""
        echo "STATUS_BLOCKER=\"\""
        echo "STATUS_TIMESTAMP=\"\""
        return 1
    fi

    # Check staleness
    local is_stale="false"
    if is_file_stale "$status_file" "$STATUS_MAX_AGE" 2>/dev/null; then
        is_stale="true"
    fi

    # Parse the file
    local content
    content=$(cat "$status_file")

    local timestamp status summary files next blocker
    timestamp=$(echo "$content" | grep -E "^TIMESTAMP:" | head -1 | cut -d: -f2- | sed 's/^ *//')
    status=$(echo "$content" | grep -E "^STATUS:" | head -1 | cut -d: -f2 | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    summary=$(echo "$content" | grep -E "^SUMMARY:" | head -1 | cut -d: -f2- | sed 's/^ *//')
    files=$(echo "$content" | grep -E "^FILES:" | head -1 | cut -d: -f2- | sed 's/^ *//')
    next=$(echo "$content" | grep -E "^NEXT:" | head -1 | cut -d: -f2- | sed 's/^ *//')
    blocker=$(echo "$content" | grep -E "^BLOCKER:" | head -1 | cut -d: -f2- | sed 's/^ *//')

    # Validate
    local is_valid="false"
    if is_valid_status "$status"; then
        is_valid="true"
    fi

    echo "STATUS_VALID=$is_valid"
    echo "STATUS_STALE=$is_stale"
    echo "STATUS_VALUE=\"$status\""
    echo "STATUS_SUMMARY=\"$summary\""
    echo "STATUS_FILES=\"$files\""
    echo "STATUS_NEXT=\"$next\""
    echo "STATUS_BLOCKER=\"$blocker\""
    echo "STATUS_TIMESTAMP=\"$timestamp\""
}

# Clear STATUS file (move to .status.processed)
clear_status() {
    local status_file="${1:-$STATUS_FILE}"

    if [[ -f "$status_file" ]]; then
        local processed_file="${status_file}.processed"
        mv "$status_file" "$processed_file"
        log_debug "STATUS cleared: moved to $processed_file" 2>/dev/null || true
    fi
}

# Check if STATUS file exists and is valid
has_status_file() {
    local status_file="${1:-$STATUS_FILE}"

    if [[ ! -f "$status_file" ]]; then
        return 1
    fi

    # Check if it has a valid STATUS line
    grep -qE "^STATUS:\s*(COMPLETE|BLOCKED|WAITING|ERROR)" "$status_file"
}

# === Legacy compatibility ===

# Parse from file (legacy function)
parse_status_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        parse_status "$(cat "$file")"
    else
        echo "STATUS_VALUE=\"\""
        echo "STATUS_SUMMARY=\"\""
        echo "STATUS_FILES=\"\""
        echo "STATUS_NEXT=\"\""
        echo "STATUS_BLOCKER=\"\""
    fi
}

# Create a STATUS signal (for output)
create_status() {
    local status="$1"
    local summary="$2"
    local files="${3:-}"
    local next="${4:-}"
    local blocker="${5:-}"

    echo "STATUS: $status"
    echo "SUMMARY: $summary"
    [[ -n "$files" ]] && echo "FILES: $files"
    [[ -n "$next" ]] && echo "NEXT: $next"
    [[ -n "$blocker" ]] && echo "BLOCKER: $blocker"
}

# === Combined read from file + env fallback ===

# Read STATUS from file first, then fall back to CLAUDE_LAST_OUTPUT
# This is the primary function for on-stop.sh to use
read_status_with_fallback() {
    local status_file="${1:-$STATUS_FILE}"

    # Try file first
    if has_status_file "$status_file" 2>/dev/null; then
        read_status "$status_file"
        return 0
    fi

    # Fall back to environment variable
    if [[ -n "${CLAUDE_LAST_OUTPUT:-}" ]]; then
        if has_status "$CLAUDE_LAST_OUTPUT"; then
            # Parse from env var directly (avoid eval)
            local env_status env_summary env_files env_next env_blocker
            env_status=$(get_status_value "$CLAUDE_LAST_OUTPUT")
            env_summary=$(echo "$CLAUDE_LAST_OUTPUT" | grep -E "^SUMMARY:" | head -1 | cut -d: -f2- | sed 's/^ *//')
            env_files=$(echo "$CLAUDE_LAST_OUTPUT" | grep -E "^FILES:" | head -1 | cut -d: -f2- | sed 's/^ *//')
            env_next=$(echo "$CLAUDE_LAST_OUTPUT" | grep -E "^NEXT:" | head -1 | cut -d: -f2- | sed 's/^ *//')
            env_blocker=$(echo "$CLAUDE_LAST_OUTPUT" | grep -E "^BLOCKER:" | head -1 | cut -d: -f2- | sed 's/^ *//')

            echo "STATUS_VALID=true"
            echo "STATUS_STALE=false"
            echo "STATUS_VALUE=\"$env_status\""
            echo "STATUS_SUMMARY=\"$env_summary\""
            echo "STATUS_FILES=\"$env_files\""
            echo "STATUS_NEXT=\"$env_next\""
            echo "STATUS_BLOCKER=\"$env_blocker\""
            echo "STATUS_TIMESTAMP=\"\""
            echo "STATUS_SOURCE=\"env\""
            return 0
        fi
    fi

    # No STATUS found
    echo "STATUS_VALID=false"
    echo "STATUS_STALE=true"
    echo "STATUS_VALUE=\"\""
    echo "STATUS_SUMMARY=\"\""
    echo "STATUS_FILES=\"\""
    echo "STATUS_NEXT=\"\""
    echo "STATUS_BLOCKER=\"\""
    echo "STATUS_TIMESTAMP=\"\""
    echo "STATUS_SOURCE=\"none\""
    return 1
}

# Command-line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        parse)
            if [[ -n "$2" ]]; then
                parse_status "$2"
            else
                # Read from stdin
                parse_status "$(cat)"
            fi
            ;;
        parse-file)
            parse_status_file "$2"
            ;;
        has)
            has_status "$2" && echo "true" || echo "false"
            ;;
        value)
            get_status_value "$2"
            ;;
        create)
            create_status "$2" "$3" "$4" "$5" "$6"
            ;;
        write)
            write_status "$2" "$3" "$4" "$5" "$6"
            echo "STATUS written to file"
            ;;
        read)
            read_status "${2:-}"
            ;;
        read-with-fallback)
            read_status_with_fallback "${2:-}"
            ;;
        clear)
            clear_status "${2:-}"
            echo "STATUS cleared"
            ;;
        has-file)
            has_status_file "${2:-}" && echo "true" || echo "false"
            ;;
        *)
            echo "Usage: $0 {parse|parse-file|has|value|create|write|read|clear|...}"
            echo ""
            echo "Text Commands:"
            echo "  parse [text]              - Parse STATUS from text (or stdin)"
            echo "  parse-file <file>         - Parse STATUS from file"
            echo "  has <text>                - Check if text has valid STATUS"
            echo "  value <text>              - Get just the status value"
            echo "  create <status> <summary> [files] [next] [blocker]"
            echo ""
            echo "File Commands:"
            echo "  write <status> <summary> [files] [next] [blocker]"
            echo "                            - Write STATUS to work/.status"
            echo "  read [file]               - Read STATUS from file"
            echo "  read-with-fallback [file] - Read from file, then env"
            echo "  clear [file]              - Clear STATUS file"
            echo "  has-file [file]           - Check if STATUS file exists"
            ;;
    esac
fi
