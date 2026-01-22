#!/usr/bin/env bash
# tunnel.sh - SSH Tunnel Manager
# Manage persistent SSH tunnels for k8s, databases, and other services
#
# Usage:
#   ./tunnel.sh start <tunnel-name>
#   ./tunnel.sh stop <tunnel-name>
#   ./tunnel.sh status [tunnel-name]
#   ./tunnel.sh list
#   ./tunnel.sh add <name> <local-port> <remote-host:port> [bastion]
#
# Configuration: ~/.config/tunnels.conf

set -euo pipefail

CONFIG_FILE="${TUNNEL_CONFIG:-$HOME/.config/tunnels.conf}"
SOCKET_DIR="${HOME}/.ssh/tunnels"
PIDFILE_DIR="/tmp/ssh-tunnels"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $*"; }
log_err() { echo -e "${RED}[✗]${NC} $*"; }
log_debug() { echo -e "${BLUE}[·]${NC} $*"; }

# Ensure directories exist
mkdir -p "$SOCKET_DIR" "$PIDFILE_DIR"
chmod 700 "$SOCKET_DIR"

# Initialize config if not exists
init_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        cat > "$CONFIG_FILE" << 'EOF'
# SSH Tunnel Configuration
# Format: NAME|LOCAL_PORT|REMOTE_HOST:PORT|BASTION (optional)
#
# Examples:
# k8s|6443|kubernetes.default:443|user@bastion.example.com
# db|5432|postgres.internal:5432|user@bastion.example.com
# redis|6379|redis.internal:6379|user@bastion.example.com
# web|8080|internal-app:80|
#
# Add your tunnels below:

EOF
        log_info "Created config file: $CONFIG_FILE"
        log_info "Edit it to add your tunnel definitions"
    fi
}

# Parse tunnel config
get_tunnel_config() {
    local name="$1"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 1
    fi
    grep "^${name}|" "$CONFIG_FILE" 2>/dev/null | head -1
}

# List all configured tunnels
list_tunnels() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "No config file found. Run: $0 init"
        return 1
    fi
    
    echo "Configured tunnels:"
    echo "==================="
    printf "%-15s %-12s %-30s %-30s %s\n" "NAME" "LOCAL_PORT" "REMOTE" "BASTION" "STATUS"
    echo "--------------------------------------------------------------------------------------------"
    
    while IFS='|' read -r name local_port remote bastion; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        
        local status
        if is_running "$name"; then
            status="${GREEN}running${NC}"
        else
            status="${RED}stopped${NC}"
        fi
        
        printf "%-15s %-12s %-30s %-30s %b\n" "$name" "$local_port" "$remote" "${bastion:-direct}" "$status"
    done < "$CONFIG_FILE"
}

# Check if tunnel is running
is_running() {
    local name="$1"
    local pidfile="${PIDFILE_DIR}/${name}.pid"
    
    if [[ -f "$pidfile" ]]; then
        local pid
        pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        rm -f "$pidfile"
    fi
    return 1
}

# Get tunnel PID
get_pid() {
    local name="$1"
    local pidfile="${PIDFILE_DIR}/${name}.pid"
    [[ -f "$pidfile" ]] && cat "$pidfile"
}

# Start tunnel
start_tunnel() {
    local name="$1"
    
    if is_running "$name"; then
        log_warn "Tunnel '$name' already running (PID: $(get_pid "$name"))"
        return 0
    fi
    
    local config
    config=$(get_tunnel_config "$name")
    if [[ -z "$config" ]]; then
        log_err "Tunnel '$name' not found in config"
        log_info "Available tunnels:"
        list_tunnels
        return 1
    fi
    
    IFS='|' read -r _ local_port remote bastion <<< "$config"
    
    local ssh_cmd=(ssh -f -N -L "${local_port}:${remote}")
    ssh_cmd+=(-o "ServerAliveInterval=30")
    ssh_cmd+=(-o "ServerAliveCountMax=3")
    ssh_cmd+=(-o "ExitOnForwardFailure=yes")
    ssh_cmd+=(-o "ControlMaster=auto")
    ssh_cmd+=(-o "ControlPath=${SOCKET_DIR}/%r@%h-%p")
    ssh_cmd+=(-o "ControlPersist=yes")
    
    if [[ -n "$bastion" ]]; then
        ssh_cmd+=("$bastion")
    else
        # Extract host from remote for direct connection
        local remote_host="${remote%%:*}"
        ssh_cmd+=("$remote_host")
    fi
    
    log_debug "Starting tunnel: ${ssh_cmd[*]}"
    
    if "${ssh_cmd[@]}"; then
        # Find the SSH process and save PID
        sleep 1
        local pid
        pid=$(pgrep -f "ssh.*-L ${local_port}:${remote}" | head -1)
        
        if [[ -n "$pid" ]]; then
            echo "$pid" > "${PIDFILE_DIR}/${name}.pid"
            log_info "Tunnel '$name' started (PID: $pid)"
            log_info "  Local:  localhost:${local_port}"
            log_info "  Remote: ${remote}"
            [[ -n "$bastion" ]] && log_info "  Via:    ${bastion}"
        else
            log_err "Tunnel started but couldn't find PID"
            return 1
        fi
    else
        log_err "Failed to start tunnel '$name'"
        return 1
    fi
}

# Stop tunnel
stop_tunnel() {
    local name="$1"
    local pidfile="${PIDFILE_DIR}/${name}.pid"
    
    if [[ -f "$pidfile" ]]; then
        local pid
        pid=$(cat "$pidfile")
        if kill "$pid" 2>/dev/null; then
            rm -f "$pidfile"
            log_info "Tunnel '$name' stopped (was PID: $pid)"
        else
            rm -f "$pidfile"
            log_warn "Tunnel '$name' was not running (stale pidfile removed)"
        fi
    else
        # Try to find by pattern
        local config
        config=$(get_tunnel_config "$name")
        if [[ -n "$config" ]]; then
            IFS='|' read -r _ local_port remote _ <<< "$config"
            if pkill -f "ssh.*-L ${local_port}:${remote}" 2>/dev/null; then
                log_info "Tunnel '$name' stopped (found by pattern)"
            else
                log_warn "Tunnel '$name' not running"
            fi
        else
            log_err "Tunnel '$name' not found"
        fi
    fi
}

# Show tunnel status
status_tunnel() {
    local name="${1:-}"
    
    if [[ -z "$name" ]]; then
        # Show all
        list_tunnels
        return
    fi
    
    if is_running "$name"; then
        local pid
        pid=$(get_pid "$name")
        local config
        config=$(get_tunnel_config "$name")
        IFS='|' read -r _ local_port remote bastion <<< "$config"
        
        log_info "Tunnel '$name': ${GREEN}running${NC} (PID: $pid)"
        echo "  Local:  localhost:${local_port}"
        echo "  Remote: ${remote}"
        [[ -n "$bastion" ]] && echo "  Via:    ${bastion}"
        
        # Check if port is actually listening
        if command -v lsof &>/dev/null; then
            if lsof -i ":${local_port}" &>/dev/null; then
                echo "  Port:   ${GREEN}listening${NC}"
            else
                echo "  Port:   ${YELLOW}not listening${NC}"
            fi
        fi
    else
        log_info "Tunnel '$name': ${RED}stopped${NC}"
    fi
}

# Add new tunnel to config
add_tunnel() {
    local name="$1"
    local local_port="$2"
    local remote="$3"
    local bastion="${4:-}"
    
    init_config
    
    if get_tunnel_config "$name" &>/dev/null; then
        log_err "Tunnel '$name' already exists in config"
        return 1
    fi
    
    echo "${name}|${local_port}|${remote}|${bastion}" >> "$CONFIG_FILE"
    log_info "Added tunnel '$name' to config"
    log_info "  Local:  localhost:${local_port}"
    log_info "  Remote: ${remote}"
    [[ -n "$bastion" ]] && log_info "  Via:    ${bastion}"
}

# Stop all tunnels
stop_all() {
    log_info "Stopping all tunnels..."
    for pidfile in "${PIDFILE_DIR}"/*.pid; do
        [[ -f "$pidfile" ]] || continue
        local name
        name=$(basename "$pidfile" .pid)
        stop_tunnel "$name"
    done
}

# Main
case "${1:-help}" in
    init)
        init_config
        ;;
    start)
        start_tunnel "${2:?Usage: $0 start <tunnel-name>}"
        ;;
    stop)
        if [[ "${2:-}" == "all" ]]; then
            stop_all
        else
            stop_tunnel "${2:?Usage: $0 stop <tunnel-name|all>}"
        fi
        ;;
    restart)
        name="${2:?Usage: $0 restart <tunnel-name>}"
        stop_tunnel "$name"
        sleep 1
        start_tunnel "$name"
        ;;
    status)
        status_tunnel "${2:-}"
        ;;
    list)
        list_tunnels
        ;;
    add)
        add_tunnel "${2:?}" "${3:?}" "${4:?}" "${5:-}"
        ;;
    help|--help|-h)
        cat << 'EOF'
SSH Tunnel Manager

Usage:
  tunnel.sh init                                    Initialize config file
  tunnel.sh start <name>                            Start a tunnel
  tunnel.sh stop <name|all>                         Stop tunnel(s)
  tunnel.sh restart <name>                          Restart a tunnel
  tunnel.sh status [name]                           Show tunnel status
  tunnel.sh list                                    List all tunnels
  tunnel.sh add <name> <local> <remote> [bastion]   Add tunnel to config

Examples:
  tunnel.sh add k8s 6443 kubernetes:443 user@bastion
  tunnel.sh add db 5432 postgres.internal:5432 user@bastion
  tunnel.sh start k8s
  tunnel.sh status

Config file: ~/.config/tunnels.conf
EOF
        ;;
    *)
        log_err "Unknown command: $1"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
