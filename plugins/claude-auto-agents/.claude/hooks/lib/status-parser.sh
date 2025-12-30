#!/bin/bash
# status-parser.sh - Parse STATUS signals from Claude output
#
# Extracts STATUS, SUMMARY, FILES, NEXT, BLOCKER from output text

# Parse STATUS signal from text
# Usage: parse_status "text with STATUS: COMPLETE etc"
parse_status() {
    local text="$1"

    # Extract each field
    local status=$(echo "$text" | grep -E "^STATUS:" | head -1 | cut -d: -f2 | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    local summary=$(echo "$text" | grep -E "^SUMMARY:" | head -1 | cut -d: -f2- | sed 's/^ *//')
    local files=$(echo "$text" | grep -E "^FILES:" | head -1 | cut -d: -f2- | sed 's/^ *//')
    local next=$(echo "$text" | grep -E "^NEXT:" | head -1 | cut -d: -f2- | sed 's/^ *//')
    local blocker=$(echo "$text" | grep -E "^BLOCKER:" | head -1 | cut -d: -f2- | sed 's/^ *//')

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

# Parse from file
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

# Create a STATUS signal
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
        *)
            echo "Usage: $0 {parse|parse-file|has|value|create}"
            echo ""
            echo "Commands:"
            echo "  parse [text]              - Parse STATUS from text (or stdin)"
            echo "  parse-file <file>         - Parse STATUS from file"
            echo "  has <text>                - Check if text has valid STATUS"
            echo "  value <text>              - Get just the status value"
            echo "  create <status> <summary> [files] [next] [blocker]"
            echo "                            - Create a STATUS signal"
            ;;
    esac
fi
