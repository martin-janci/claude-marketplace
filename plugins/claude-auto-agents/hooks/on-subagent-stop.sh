#!/usr/bin/env bash
# Handle SubagentStop event for multi-agent coordination
# Called when a spawned subagent completes its work

set -euo pipefail

WORK_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/work"
AGENT_HISTORY="${WORK_DIR}/.agent-history.jsonl"
RUNNING_AGENTS="${WORK_DIR}/.running-agents.json"
DEBUG_LOG="${WORK_DIR}/.debug.log"

# Debug logging
debug() {
    if [[ "${CLAUDE_DEBUG:-0}" == "1" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SubagentStop] $*" >> "$DEBUG_LOG"
    fi
}

# Get subagent info from environment/stdin
AGENT_ID="${CLAUDE_SUBAGENT_ID:-unknown}"
AGENT_TYPE="${CLAUDE_SUBAGENT_TYPE:-unknown}"
AGENT_STATUS="${CLAUDE_SUBAGENT_STATUS:-unknown}"

debug "Subagent stopped: id=$AGENT_ID type=$AGENT_TYPE status=$AGENT_STATUS"

# Ensure work directory exists
mkdir -p "$WORK_DIR"

# Log subagent completion to history
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat >> "$AGENT_HISTORY" << EOF
{"event":"subagent_stop","agent_id":"$AGENT_ID","agent_type":"$AGENT_TYPE","status":"$AGENT_STATUS","timestamp":"$TIMESTAMP"}
EOF

# Update running agents tracking
if [[ -f "$RUNNING_AGENTS" ]]; then
    # Remove completed agent from tracking
    TMP_FILE=$(mktemp)
    jq --arg id "$AGENT_ID" 'del(.[$id])' "$RUNNING_AGENTS" > "$TMP_FILE" 2>/dev/null || echo "{}" > "$TMP_FILE"
    mv "$TMP_FILE" "$RUNNING_AGENTS"
    debug "Removed agent $AGENT_ID from running agents"
fi

# Check if this was a critical agent (orchestrator, pr-shepherd)
CRITICAL_AGENTS=("orchestrator" "pr-lifecycle-shepherd" "pr-shepherd")
IS_CRITICAL=false
for critical in "${CRITICAL_AGENTS[@]}"; do
    if [[ "$AGENT_TYPE" == "$critical" ]]; then
        IS_CRITICAL=true
        break
    fi
done

# If critical agent failed, log to blockers
if [[ "$IS_CRITICAL" == true && "$AGENT_STATUS" != "COMPLETE" ]]; then
    BLOCKERS_FILE="${WORK_DIR}/blockers.md"
    {
        echo ""
        echo "## Critical Agent Failure - $(date '+%Y-%m-%d %H:%M')"
        echo "- Agent: $AGENT_TYPE (ID: $AGENT_ID)"
        echo "- Status: $AGENT_STATUS"
        echo "- Action Required: Investigate failure and restart if needed"
    } >> "$BLOCKERS_FILE"
    debug "Logged critical agent failure to blockers"
fi

# Output summary for parent agent
echo "SUBAGENT_COMPLETED=$AGENT_ID"
echo "SUBAGENT_TYPE=$AGENT_TYPE"
echo "SUBAGENT_STATUS=$AGENT_STATUS"

debug "SubagentStop handler completed"
exit 0
