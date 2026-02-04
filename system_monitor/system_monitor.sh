#!/bin/bash

#############################################
# Improved System Monitor with Safety Features
#############################################

CONFIG_FILE="${CONFIG_FILE:-./monitor_config.conf}"
LOG_FILE="${LOG_FILE:-./monitor.log}"
CSV_FILE="${CSV_FILE:-./system_metrics.csv}"
INTERVAL=${INTERVAL:-5}

# Colors for dashboard
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Load config if exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    # Defaults
    CPU_THRESHOLD=80
    MEM_THRESHOLD=85
    DISK_THRESHOLD=90
    AUTO_KILL_ENABLED=false
    PROTECTED_PROCESSES="systemd init bash sshd"
fi

# Initialize CSV if not exists
if [[ ! -f "$CSV_FILE" ]]; then
    echo "Timestamp,CPU_Usage(%),Memory_Usage(%),Disk_Usage(%),RX_KB/s,TX_KB/s,Top_Process,Top_Process_CPU" > "$CSV_FILE"
fi

# Track recently killed processes to avoid repeat kills
KILLED_PIDS=()
KILL_COOLDOWN=60  # Don't kill same PID again within 60 seconds

log_message() {
    local level=$1
    local message=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
}

get_cpu() {
    # More reliable CPU calculation
    top -bn2 -d 0.5 | grep "Cpu(s)" | tail -1 | awk '{print 100 - $8}' | cut -d'.' -f1
}

get_memory() {
    free | awk '/Mem/ {printf "%.1f", ($3/$2) * 100}'
}

get_disk() {
    df / | awk 'NR==2 {print $5}' | tr -d '%'
}

get_network() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [[ -z "$interface" ]]; then
        # Fallback to first active interface
        interface=$(ls /sys/class/net/ | grep -v lo | head -1)
    fi
    
    if [[ -z "$interface" ]] || [[ ! -d "/sys/class/net/$interface" ]]; then
        echo "0 0"
        return
    fi
    
    local RX1=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo 0)
    local TX1=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo 0)
    
    sleep 1
    
    local RX2=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo 0)
    local TX2=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo 0)
    
    local RX_RATE=$(( (RX2 - RX1) / 1024 ))
    local TX_RATE=$(( (TX2 - TX1) / 1024 ))
    
    echo "$RX_RATE $TX_RATE"
}

top_processes() {
    ps -eo pid,user,comm,%cpu,%mem --sort=-%cpu | head -n 11
}

is_protected_process() {
    local pid=$1
    local cmd=$(ps -p "$pid" -o comm= 2>/dev/null)
    
    if [[ -z "$cmd" ]]; then
        return 1  # Process doesn't exist
    fi
    
    # Check if process is in protected list
    for protected in $PROTECTED_PROCESSES; do
        if [[ "$cmd" == *"$protected"* ]]; then
            return 0  # Protected
        fi
    done
    
    return 1  # Not protected
}

was_recently_killed() {
    local pid=$1
    local now=$(date +%s)
    
    # Clean up old entries from killed list
    local new_killed=()
    for entry in "${KILLED_PIDS[@]}"; do
        local killed_pid=$(echo "$entry" | cut -d':' -f1)
        local killed_time=$(echo "$entry" | cut -d':' -f2)
        
        if (( now - killed_time < KILL_COOLDOWN )); then
            new_killed+=("$entry")
        fi
    done
    KILLED_PIDS=("${new_killed[@]}")
    
    # Check if PID was recently killed
    for entry in "${KILLED_PIDS[@]}"; do
        local killed_pid=$(echo "$entry" | cut -d':' -f1)
        if [[ "$killed_pid" == "$pid" ]]; then
            return 0  # Recently killed
        fi
    done
    
    return 1  # Not recently killed
}

get_top_resource_hog() {
    # Get the highest CPU consuming process (excluding this monitor)
    ps -eo pid,comm,%cpu --sort=-%cpu | \
        awk -v monitor="$0" 'NR>1 && $2 != "system_monito" && $2 != "top" && $2 != "ps" {print $1"|"$2"|"$3; exit}'
}

safe_kill_process() {
    local pid=$1
    local reason=$2
    
    # Verify process still exists
    if ! ps -p "$pid" > /dev/null 2>&1; then
        log_message "WARN" "Process PID=$pid no longer exists, skipping kill"
        return 1
    fi
    
    # Check if protected
    if is_protected_process "$pid"; then
        local cmd=$(ps -p "$pid" -o comm=)
        log_message "WARN" "Process PID=$pid ($cmd) is protected, skipping kill"
        return 1
    fi
    
    # Check if recently killed
    if was_recently_killed "$pid"; then
        log_message "WARN" "Process PID=$pid was recently killed, skipping (cooldown active)"
        return 1
    fi
    
    # Get process info before killing
    local proc_info=$(ps -p "$pid" -o user=,comm=,%cpu=,%mem= 2>/dev/null)
    
    if [[ -z "$proc_info" ]]; then
        log_message "WARN" "Cannot get info for PID=$pid, process may have exited"
        return 1
    fi
    
    log_message "ACTION" "Killing process: PID=$pid, Info: $proc_info, Reason: $reason"
    
    # Try graceful kill first (SIGTERM)
    kill -15 "$pid" 2>/dev/null
    
    # Wait 2 seconds for graceful shutdown
    sleep 2
    
    # Check if still running
    if ps -p "$pid" > /dev/null 2>&1; then
        log_message "ACTION" "Process PID=$pid still running, sending SIGKILL"
        kill -9 "$pid" 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log_message "ACTION" "Successfully force-killed PID=$pid"
        else
            log_message "ERROR" "Failed to kill PID=$pid: $?"
            return 1
        fi
    else
        log_message "ACTION" "Process PID=$pid terminated gracefully"
    fi
    
    # Add to recently killed list
    KILLED_PIDS+=("$pid:$(date +%s)")
    
    return 0
}

take_action() {
    local TYPE=$1
    local VALUE=$2
    
    log_message "ALERT" "$TYPE usage high (${VALUE}%)"
    
    # Only auto-kill if enabled in config
    if [[ "${AUTO_KILL_ENABLED:-false}" != "true" ]]; then
        log_message "INFO" "Auto-kill disabled, manual intervention required"
        return
    fi
    
    # Kill highest CPU consumer if CPU critical
    if [[ "$TYPE" == "CPU" ]] && (( VALUE >= ${CPU_KILL_THRESHOLD:-95} )); then
        local hog_info=$(get_top_resource_hog)
        
        if [[ -z "$hog_info" ]]; then
            log_message "WARN" "No suitable process found to kill"
            return
        fi
        
        local pid=$(echo "$hog_info" | cut -d'|' -f1)
        local cmd=$(echo "$hog_info" | cut -d'|' -f2)
        local cpu=$(echo "$hog_info" | cut -d'|' -f3)
        
        log_message "WARN" "Top CPU consumer: PID=$pid CMD=$cmd CPU=${cpu}%"
        
        # Only kill if process is using significant CPU
        if (( $(echo "$cpu > 50" | bc -l) )); then
            safe_kill_process "$pid" "High CPU usage (${cpu}%)"
        else
            log_message "INFO" "Top process CPU usage (${cpu}%) below kill threshold"
        fi
    fi
    
    # Handle high memory
    if [[ "$TYPE" == "MEMORY" ]] && (( VALUE >= ${MEM_KILL_THRESHOLD:-95} )); then
        # Get top memory consumer
        local mem_hog=$(ps -eo pid,comm,%mem --sort=-%mem | awk 'NR==2 {print $1"|"$2"|"$3}')
        
        if [[ -n "$mem_hog" ]]; then
            local pid=$(echo "$mem_hog" | cut -d'|' -f1)
            local cmd=$(echo "$mem_hog" | cut -d'|' -f2)
            local mem=$(echo "$mem_hog" | cut -d'|' -f3)
            
            log_message "WARN" "Top memory consumer: PID=$pid CMD=$cmd MEM=${mem}%"
            
            if (( $(echo "$mem > 20" | bc -l) )); then
                safe_kill_process "$pid" "High memory usage (${mem}%)"
            fi
        fi
    fi
}

draw_bar() {
    local value=$1
    local max=${2:-100}
    local width=40
    local color=$3
    
    local filled=$(awk "BEGIN {printf \"%.0f\", ($value/$max)*$width}")
    local empty=$((width - filled))
    
    echo -n "["
    if [[ -n "$color" ]]; then
        echo -n -e "$color"
    fi
    
    for ((i=0; i<filled; i++)); do echo -n "█"; done
    
    if [[ -n "$color" ]]; then
        echo -n -e "$NC"
    fi
    
    for ((i=0; i<empty; i++)); do echo -n "░"; done
    echo -n "]"
}

dashboard() {
    echo "Starting dashboard mode (Ctrl+C to exit)..."
    sleep 2
    
    while true; do
        clear
        
        CPU=$(get_cpu)
        MEM=$(get_memory)
        DISK=$(get_disk)
        read RX TX <<< $(get_network)
        
        # Determine colors
        local cpu_color=$GREEN
        (( CPU > CPU_THRESHOLD )) && cpu_color=$RED
        (( CPU > CPU_THRESHOLD * 7 / 10 )) && (( CPU <= CPU_THRESHOLD )) && cpu_color=$YELLOW
        
        local mem_color=$GREEN
        (( $(echo "$MEM > $MEM_THRESHOLD" | bc -l) )) && mem_color=$RED
        (( $(echo "$MEM > $MEM_THRESHOLD * 0.7" | bc -l) )) && (( $(echo "$MEM <= $MEM_THRESHOLD" | bc -l) )) && mem_color=$YELLOW
        
        local disk_color=$GREEN
        (( DISK > DISK_THRESHOLD )) && disk_color=$RED
        (( DISK > DISK_THRESHOLD * 7 / 10 )) && (( DISK <= DISK_THRESHOLD )) && disk_color=$YELLOW
        
        # Header
        echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${CYAN}║                      SYSTEM RESOURCE MONITOR - DASHBOARD                     ║${NC}"
        echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BOLD}${BLUE}📅 Time:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
        echo -e "${BOLD}${BLUE}🔄 Interval:${NC} ${INTERVAL}s | ${BOLD}${BLUE}Auto-Kill:${NC} ${AUTO_KILL_ENABLED:-false}"
        echo ""
        
        # System Metrics
        echo -e "${BOLD}${MAGENTA}┌─ SYSTEM METRICS ─────────────────────────────────────────────────────────────┐${NC}"
        echo ""
        
        # CPU
        echo -e "${BOLD}  🖥️  CPU Usage:${NC} ${cpu_color}${BOLD}${CPU}%${NC} (threshold: ${CPU_THRESHOLD}%)"
        echo -n "     "
        draw_bar "$CPU" 100 "$cpu_color"
        echo ""
        echo ""
        
        # Memory
        echo -e "${BOLD}  💾 Memory Usage:${NC} ${mem_color}${BOLD}${MEM}%${NC} (threshold: ${MEM_THRESHOLD}%)"
        echo -n "     "
        draw_bar "$MEM" 100 "$mem_color"
        echo ""
        echo ""
        
        # Disk
        echo -e "${BOLD}  💿 Disk Usage:${NC} ${disk_color}${BOLD}${DISK}%${NC} (threshold: ${DISK_THRESHOLD}%)"
        echo -n "     "
        draw_bar "$DISK" 100 "$disk_color"
        echo ""
        echo ""
        
        # Network
        echo -e "${BOLD}  🌐 Network:${NC}"
        echo -e "     ${BOLD}↓ RX:${NC} ${GREEN}${RX}${NC} KB/s"
        echo -e "     ${BOLD}↑ TX:${NC} ${YELLOW}${TX}${NC} KB/s"
        echo ""
        
        echo -e "${BOLD}${MAGENTA}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        
        # Top 10 Processes
        echo -e "${BOLD}${MAGENTA}┌─ TOP 10 RESOURCE-CONSUMING PROCESSES ────────────────────────────────────────┐${NC}"
        echo ""
        printf "${BOLD}%-8s %-10s %-15s %-8s %-8s${NC}\n" "PID" "USER" "COMMAND" "CPU%" "MEM%"
        echo "────────────────────────────────────────────────────────────────────────────────"
        
        top_processes | tail -n +2 | while read line; do
            local pid=$(echo "$line" | awk '{print $1}')
            local user=$(echo "$line" | awk '{print $2}')
            local cmd=$(echo "$line" | awk '{print $3}')
            local cpu=$(echo "$line" | awk '{print $4}')
            local mem=$(echo "$line" | awk '{print $5}')
            
            # Color code high CPU
            local proc_color=$NC
            (( $(echo "$cpu > 50" | bc -l) )) && proc_color=$RED
            (( $(echo "$cpu > 20 && $cpu <= 50" | bc -l) )) && proc_color=$YELLOW
            
            printf "${proc_color}%-8s %-10s %-15s %-8s %-8s${NC}\n" "$pid" "$user" "$cmd" "$cpu" "$mem"
        done
        
        echo -e "${BOLD}${MAGENTA}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        
        # Status
        echo -e "${BOLD}${BLUE}Status:${NC}"
        local alerts=0
        (( CPU > CPU_THRESHOLD )) && { echo -e "  ${RED}⚠${NC}  CPU usage is high (${CPU}%)"; ((alerts++)); }
        (( $(echo "$MEM > $MEM_THRESHOLD" | bc -l) )) && { echo -e "  ${RED}⚠${NC}  Memory usage is high (${MEM}%)"; ((alerts++)); }
        (( DISK > DISK_THRESHOLD )) && { echo -e "  ${RED}⚠${NC}  Disk usage is high (${DISK}%)"; ((alerts++)); }
        
        if [[ $alerts -eq 0 ]]; then
            echo -e "  ${GREEN}✓${NC} All metrics within normal range"
        fi
        
        echo ""
        echo -e "${CYAN}Press Ctrl+C to exit dashboard${NC}"
        
        sleep "$INTERVAL"
    done
}

daemon() {
    log_message "INFO" "Starting system monitor daemon (PID: $$)"
    echo "Daemon mode started. Check $LOG_FILE for alerts."
    
    while true; do
        CPU=$(get_cpu)
        MEM=$(get_memory)
        DISK=$(get_disk)
        read RX TX <<< $(get_network)
        
        # Get top process info
        local top_proc=$(get_top_resource_hog)
        local top_proc_name=$(echo "$top_proc" | cut -d'|' -f2)
        local top_proc_cpu=$(echo "$top_proc" | cut -d'|' -f3)
        
        # Record to CSV
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$CPU,$MEM,$DISK,$RX,$TX,$top_proc_name,$top_proc_cpu" >> "$CSV_FILE"
        
        # Check thresholds
        (( CPU > CPU_THRESHOLD )) && take_action "CPU" "$CPU"
        (( $(echo "$MEM > $MEM_THRESHOLD" | bc -l) )) && take_action "MEMORY" "$MEM"
        (( DISK > DISK_THRESHOLD )) && take_action "DISK" "$DISK"
        
        sleep "$INTERVAL"
    done
}

show_help() {
    cat << EOF
Usage: $0 {daemon|dashboard} [OPTIONS]

MODES:
  daemon       Run as background daemon
  dashboard    Display real-time dashboard
  help         Show this help message

EXAMPLES:
  $0 dashboard              # Interactive dashboard
  $0 daemon                 # Run daemon in background
  $0 daemon &               # Run daemon as background process

CONFIGURATION:
  Edit $CONFIG_FILE to customize:
    - CPU_THRESHOLD (default: 80)
    - MEM_THRESHOLD (default: 85)
    - DISK_THRESHOLD (default: 90)
    - AUTO_KILL_ENABLED (default: false)
    - PROTECTED_PROCESSES (e.g., "systemd init sshd")

FILES:
  $LOG_FILE      - Alert and action logs
  $CSV_FILE      - Historical metrics
  $CONFIG_FILE   - Configuration

SAFETY:
  Set AUTO_KILL_ENABLED=false in config for manual intervention only.
  Set AUTO_KILL_ENABLED=true to enable automated process killing.
  Add critical processes to PROTECTED_PROCESSES list.

EOF
}

# Main
case "$1" in
    daemon)
        daemon
        ;;
    dashboard)
        dashboard
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Error: Invalid mode '$1'"
        echo ""
        show_help
        exit 1
        ;;
esac