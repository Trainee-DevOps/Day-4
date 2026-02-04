#!/bin/bash

CONFIG_FILE="./monitor_config.conf"
LOG_FILE="./monitor.log"
CSV_FILE="./system_metrics.csv"
INTERVAL=5

# Load config
source "$CONFIG_FILE"

# Initialize CSV if not exists
if [[ ! -f "$CSV_FILE" ]]; then
    echo "Timestamp,CPU_Usage(%),Memory_Usage(%),Disk_Usage(%),RX_KB/s,TX_KB/s" > "$CSV_FILE"
fi

get_cpu() {
    top -bn1 | awk '/Cpu/ {print 100 - $8}'
}

get_memory() {
    free | awk '/Mem/ {printf "%.2f", $3/$2 * 100}'
}

get_disk() {
    df / | awk 'NR==2 {print $5}' | tr -d '%'
}

get_network() {
    RX1=$(cat /proc/net/dev | awk '/eth|ens|enp/ {rx+=$2} END {print rx}')
    TX1=$(cat /proc/net/dev | awk '/eth|ens|enp/ {tx+=$10} END {print tx}')
    sleep 1
    RX2=$(cat /proc/net/dev | awk '/eth|ens|enp/ {rx+=$2} END {print rx}')
    TX2=$(cat /proc/net/dev | awk '/eth|ens|enp/ {tx+=$10} END {print tx}')

    RX_RATE=$(( (RX2 - RX1) / 1024 ))
    TX_RATE=$(( (TX2 - TX1) / 1024 ))

    echo "$RX_RATE $TX_RATE"
}

top_processes() {
    ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 11
}

take_action() {
    local TYPE=$1
    local VALUE=$2

    echo "$(date) WARNING: $TYPE usage high ($VALUE%)" >> "$LOG_FILE"

    # Kill highest CPU consumer if CPU critical
    if [[ "$TYPE" == "CPU" ]]; then
        PID=$(ps -eo pid,%cpu --sort=-%cpu | awk 'NR==2 {print $1}')
        echo "$(date) ACTION: Killing process PID=$PID" >> "$LOG_FILE"
        kill -9 "$PID"
    fi
}

dashboard() {
    while true; do
        clear
        CPU=$(get_cpu)
        MEM=$(get_memory)
        DISK=$(get_disk)
        read RX TX <<< $(get_network)

        echo "================= SYSTEM MONITOR DASHBOARD ================="
        echo "Time      : $(date)"
        echo "------------------------------------------------------------"
        printf "CPU Usage : %.2f%%\n" "$CPU"
        printf "Memory    : %.2f%%\n" "$MEM"
        printf "Disk      : %s%%\n" "$DISK"
        echo "Network   : RX ${RX}KB/s | TX ${TX}KB/s"
        echo "------------------------------------------------------------"
        echo "Top 10 Resource Consuming Processes"
        echo "PID     COMMAND        CPU%   MEM%"
        top_processes
        echo "============================================================"

        sleep "$INTERVAL"
    done
}

daemon() {
    while true; do
        CPU=$(get_cpu)
        MEM=$(get_memory)
        DISK=$(get_disk)
        read RX TX <<< $(get_network)

        echo "$(date),$CPU,$MEM,$DISK,$RX,$TX" >> "$CSV_FILE"

        (( $(echo "$CPU > $CPU_THRESHOLD" | bc -l) )) && take_action "CPU" "$CPU"
        (( $(echo "$MEM > $MEM_THRESHOLD" | bc -l) )) && take_action "MEMORY" "$MEM"
        (( DISK > DISK_THRESHOLD )) && take_action "DISK" "$DISK"

        sleep "$INTERVAL"
    done
}

case "$1" in
    daemon)
        daemon
        ;;
    dashboard)
        dashboard
        ;;
    *)
        echo "Usage: $0 {daemon|dashboard}"
        ;;
esac
