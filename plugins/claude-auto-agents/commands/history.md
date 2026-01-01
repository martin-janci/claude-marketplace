# /history - Iteration History

Shows detailed history of loop iterations with timing and status.

## Usage
/history [count]

- `count` - Number of entries to show (default: 20)

!bash cat << 'SCRIPT' | bash
#!/bin/bash
WORK_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/work"
COUNT="${1:-20}"

echo "# Iteration History (last $COUNT)"
echo ""

if [[ ! -f "$WORK_DIR/.iteration-history.jsonl" ]]; then
    echo "No iteration history found."
    echo ""
    echo "Run /loop to start tracking iterations."
    exit 0
fi

echo "| Iter | Item | Status | Duration | Summary |"
echo "|------|------|--------|----------|---------|"

tail -"$COUNT" "$WORK_DIR/.iteration-history.jsonl" | while IFS= read -r line; do
    # Extract fields from JSON using grep/cut (portable)
    iter=$(echo "$line" | grep -o '"iteration":[0-9]*' | cut -d: -f2)
    item=$(echo "$line" | grep -o '"item":"[^"]*"' | cut -d'"' -f4)
    status=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    elapsed=$(echo "$line" | grep -o '"elapsed_ms":[0-9]*' | cut -d: -f2)
    summary=$(echo "$line" | grep -o '"summary":"[^"]*"' | cut -d'"' -f4)

    # Format duration
    if [[ -n "$elapsed" ]]; then
        if [[ $elapsed -gt 60000 ]]; then
            mins=$((elapsed / 60000))
            secs=$(((elapsed % 60000) / 1000))
            duration="${mins}m${secs}s"
        elif [[ $elapsed -gt 1000 ]]; then
            secs=$((elapsed / 1000))
            duration="${secs}s"
        else
            duration="${elapsed}ms"
        fi
    else
        duration="-"
    fi

    # Truncate summary if too long
    if [[ ${#summary} -gt 40 ]]; then
        summary="${summary:0:37}..."
    fi

    # Format item (default to n/a)
    [[ -z "$item" ]] && item="n/a"

    echo "| ${iter:-?} | $item | ${status:-?} | $duration | ${summary:-} |"
done

echo ""
echo "---"
echo "Total entries: $(wc -l < "$WORK_DIR/.iteration-history.jsonl" | tr -d ' ')"

# Show total elapsed time if available
if [[ -f "$WORK_DIR/.loop-state" ]]; then
    total_elapsed=$(grep "TOTAL_ELAPSED_MS" "$WORK_DIR/.loop-state" 2>/dev/null | cut -d= -f2)
    if [[ -n "$total_elapsed" && "$total_elapsed" != "0" ]]; then
        if [[ $total_elapsed -gt 60000 ]]; then
            total_mins=$((total_elapsed / 60000))
            total_secs=$(((total_elapsed % 60000) / 1000))
            echo "Total runtime: ${total_mins}m${total_secs}s"
        else
            total_secs=$((total_elapsed / 1000))
            echo "Total runtime: ${total_secs}s"
        fi
    fi
fi
SCRIPT
