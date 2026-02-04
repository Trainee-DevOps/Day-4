# System Resource Monitor

A comprehensive Bash-based system monitoring tool that tracks CPU, memory, disk, and network usage in real-time with automated alerting and optional process management capabilities.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [How It Works](#how-it-works)
- [Safety Features](#safety-features)
- [File Structure](#file-structure)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This system monitor provides two operational modes:
1. **Dashboard Mode**: Real-time visual interface with color-coded metrics
2. **Daemon Mode**: Background service with automated monitoring and logging

## ✨ Features

### Core Monitoring
- **CPU Usage**: Real-time CPU utilization tracking
- **Memory Usage**: RAM consumption monitoring
- **Disk Usage**: Root partition space tracking
- **Network Bandwidth**: RX/TX rate monitoring (KB/s)
- **Process Tracking**: Top 10 resource-consuming processes

### Automated Actions
- Configurable threshold-based alerts
- Automated process termination (optional)
- Protected process safeguards
- Kill cooldown mechanism to prevent rapid re-kills

### Data Management
- Historical metrics logging to CSV
- Detailed event logging
- Configurable thresholds
- Customizable monitoring intervals

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    System Monitor                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐              ┌──────────────┐        │
│  │   Dashboard  │              │    Daemon    │        │
│  │     Mode     │              │     Mode     │        │
│  └──────┬───────┘              └──────┬───────┘        │
│         │                              │                │
│         └──────────┬───────────────────┘                │
│                    │                                    │
│         ┌──────────▼──────────┐                        │
│         │  Data Collection    │                        │
│         │  - get_cpu()        │                        │
│         │  - get_memory()     │                        │
│         │  - get_disk()       │                        │
│         │  - get_network()    │                        │
│         │  - top_processes()  │                        │
│         └──────────┬──────────┘                        │
│                    │                                    │
│         ┌──────────▼──────────┐                        │
│         │ Threshold Analysis  │                        │
│         │  - CPU vs threshold │                        │
│         │  - MEM vs threshold │                        │
│         │  - DISK vs threshold│                        │
│         └──────────┬──────────┘                        │
│                    │                                    │
│         ┌──────────▼──────────┐                        │
│         │   Action Handler    │                        │
│         │  - Log alerts       │                        │
│         │  - Kill processes   │                        │
│         │  - Safety checks    │                        │
│         └──────────┬──────────┘                        │
│                    │                                    │
│         ┌──────────▼──────────┐                        │
│         │   Output Layer      │                        │
│         │  - CSV logging      │                        │
│         │  - Text logging     │                        │
│         │  - Dashboard UI     │                        │
│         └─────────────────────┘                        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 📦 Installation

### Prerequisites
- Bash 4.0 or higher
- Linux-based operating system
- Standard utilities: `top`, `ps`, `df`, `free`, `awk`, `bc`

### Setup

1. **Clone or download the files**:
```bash
mkdir system-monitor
cd system-monitor
```

2. **Create the necessary files**:
   - `system_monitor.sh` (main script)
   - `monitor_config.conf` (configuration)

3. **Make the script executable**:
```bash
chmod +x system_monitor.sh
```

4. **Verify permissions**:
```bash
ls -l system_monitor.sh
# Should show: -rwxr-xr-x
```

## 🚀 Usage

### Dashboard Mode
Display a real-time visual dashboard:

```bash
./system_monitor.sh dashboard
```

**Dashboard Features**:
- Color-coded progress bars
- Real-time metrics updates
- Top 10 processes display
- Alert indicators
- Updates every 5 seconds (configurable)

### Daemon Mode
Run as a background monitoring service:

```bash
./system_monitor.sh daemon &
```

**Daemon Features**:
- Continuous background monitoring
- Automatic threshold checking
- CSV data logging
- Alert logging to file
- Optional automated process killing

### Help
Display usage information:

```bash
./system_monitor.sh help
```

## ⚙️ Configuration

### Configuration File: `monitor_config.conf`

```properties
# Resource Thresholds (%)
CPU_THRESHOLD=80          # Alert when CPU exceeds 80%
MEM_THRESHOLD=85          # Alert when Memory exceeds 85%
DISK_THRESHOLD=90         # Alert when Disk exceeds 90%

# Auto-Kill Configuration
AUTO_KILL_ENABLED=false   # Enable/disable automatic process termination
CPU_KILL_THRESHOLD=95     # Kill processes when CPU exceeds 95%
MEM_KILL_THRESHOLD=95     # Kill processes when Memory exceeds 95%

# Protected Processes (space-separated)
PROTECTED_PROCESSES="systemd init bash sshd ssh docker dockerd kubelet kube mysql postgres nginx apache2 httpd"

# Monitoring Settings
INTERVAL=5                # Monitoring interval in seconds
KILL_COOLDOWN=60          # Seconds before same PID can be killed again
```

### Environment Variables

You can override defaults using environment variables:

```bash
# Custom config file location
CONFIG_FILE=/etc/monitor/config.conf ./system_monitor.sh dashboard

# Custom log file
LOG_FILE=/var/log/system_monitor.log ./system_monitor.sh daemon

# Custom CSV output
CSV_FILE=/data/metrics.csv ./system_monitor.sh daemon

# Custom interval
INTERVAL=10 ./system_monitor.sh dashboard
```

## 🔄 How It Works

### Workflow Overview

```
START
  │
  ├─→ Load Configuration (monitor_config.conf)
  │
  ├─→ Initialize Files (CSV, Logs)
  │
  ├─→ Select Mode (Dashboard/Daemon)
  │
  └─→ Main Loop:
       │
       ├─→ [1] Data Collection Phase
       │    ├─→ CPU: Parse 'top' output, calculate usage
       │    ├─→ Memory: Read from 'free' command
       │    ├─→ Disk: Parse 'df' output for root partition
       │    ├─→ Network: Read /sys/class/net interface stats
       │    └─→ Processes: Get top 10 from 'ps' command
       │
       ├─→ [2] Analysis Phase
       │    ├─→ Compare CPU against CPU_THRESHOLD
       │    ├─→ Compare Memory against MEM_THRESHOLD
       │    └─→ Compare Disk against DISK_THRESHOLD
       │
       ├─→ [3] Action Phase (if thresholds exceeded)
       │    ├─→ Log alert to monitor.log
       │    ├─→ Record metrics to system_metrics.csv
       │    └─→ If AUTO_KILL_ENABLED:
       │         ├─→ Identify top resource consumer
       │         ├─→ Check if process is protected
       │         ├─→ Check kill cooldown
       │         ├─→ Attempt graceful kill (SIGTERM)
       │         └─→ Force kill if needed (SIGKILL)
       │
       ├─→ [4] Output Phase
       │    ├─→ Dashboard: Render UI with color codes
       │    └─→ Daemon: Write to log files
       │
       └─→ Sleep INTERVAL seconds, repeat
```

### Detailed Component Breakdown

#### 1. **Data Collection Functions**

##### `get_cpu()`
```bash
Purpose: Calculate current CPU usage percentage
Method:
  1. Run 'top' in batch mode twice (0.5s apart)
  2. Extract "Cpu(s)" line from second output
  3. Calculate: 100 - idle_percentage
  4. Return integer CPU usage

Example Output: 45 (meaning 45% CPU usage)
```

##### `get_memory()`
```bash
Purpose: Calculate current memory usage percentage
Method:
  1. Run 'free' command
  2. Parse "Mem:" line
  3. Calculate: (used / total) × 100
  4. Return with one decimal place

Example Output: 67.3 (meaning 67.3% memory used)
```

##### `get_disk()`
```bash
Purpose: Get root partition disk usage
Method:
  1. Run 'df /' command
  2. Extract usage percentage from second line
  3. Remove '%' character
  4. Return integer value

Example Output: 82 (meaning 82% disk used)
```

##### `get_network()`
```bash
Purpose: Calculate network throughput (RX/TX rates)
Method:
  1. Identify default network interface
  2. Read RX/TX bytes from /sys/class/net/[interface]/statistics/
  3. Wait 1 second
  4. Read RX/TX bytes again
  5. Calculate: (bytes_after - bytes_before) / 1024
  6. Return: "RX_KB/s TX_KB/s"

Example Output: 1523 842 (RX: 1523 KB/s, TX: 842 KB/s)
```

##### `top_processes()`
```bash
Purpose: List top resource-consuming processes
Method:
  1. Run 'ps' with specific columns (PID, USER, COMM, CPU%, MEM%)
  2. Sort by CPU usage (descending)
  3. Return top 11 lines (header + 10 processes)

Example Output:
PID   USER    COMMAND    %CPU  %MEM
1234  root    chrome     45.2  12.3
5678  user    python     23.1  8.5
```

#### 2. **Safety Mechanisms**

##### `is_protected_process(pid)`
```bash
Purpose: Prevent killing critical system processes
Logic:
  1. Get process command name from PID
  2. Compare against PROTECTED_PROCESSES list
  3. Return 0 (protected) or 1 (not protected)

Protected by default:
  - systemd, init (system managers)
  - bash, sshd, ssh (shell and remote access)
  - docker, dockerd, kubelet (container orchestration)
  - mysql, postgres (databases)
  - nginx, apache2, httpd (web servers)
```

##### `was_recently_killed(pid)`
```bash
Purpose: Prevent rapid re-killing of same process
Logic:
  1. Maintain array of "PID:timestamp" entries
  2. Clean up entries older than KILL_COOLDOWN
  3. Check if PID exists in recent kills
  4. Return 0 (recently killed) or 1 (can be killed)

Cooldown period: 60 seconds (default)
```

##### `safe_kill_process(pid, reason)`
```bash
Purpose: Safely terminate a process with multiple checks
Workflow:
  1. Verify process still exists
  2. Check if process is protected → Skip if yes
  3. Check if recently killed → Skip if yes
  4. Log process information
  5. Send SIGTERM (graceful shutdown signal)
  6. Wait 2 seconds
  7. If still running, send SIGKILL (force kill)
  8. Add PID to recently-killed list
  9. Log success or failure

Signals used:
  - SIGTERM (15): Allows graceful cleanup
  - SIGKILL (9): Forces immediate termination
```

#### 3. **Threshold Analysis & Actions**

##### `take_action(TYPE, VALUE)`
```bash
Purpose: Handle threshold violations
Parameters:
  - TYPE: "CPU", "MEMORY", or "DISK"
  - VALUE: Current usage percentage

Logic Flow:
  1. Log alert with type and value
  2. Check if AUTO_KILL_ENABLED
  3. If disabled → Log manual intervention needed, exit
  4. If enabled and TYPE is CPU:
     a. Check if VALUE >= CPU_KILL_THRESHOLD (95%)
     b. Find top CPU consumer
     c. Verify CPU usage > 50%
     d. Call safe_kill_process()
  5. If enabled and TYPE is MEMORY:
     a. Check if VALUE >= MEM_KILL_THRESHOLD (95%)
     b. Find top memory consumer
     c. Verify memory usage > 20%
     d. Call safe_kill_process()

Safety Features:
  - Double threshold system (alert vs kill)
  - Usage verification before killing
  - Protected process checks
  - Cooldown enforcement
```

#### 4. **Dashboard Rendering**

##### `draw_bar(value, max, color)`
```bash
Purpose: Create visual progress bars
Parameters:
  - value: Current metric value
  - max: Maximum value (usually 100)
  - color: ANSI color code

Logic:
  1. Calculate filled portion: (value/max) × 40
  2. Calculate empty portion: 40 - filled
  3. Draw: [████████████░░░░░░░░]
  
  Filled: █ (colored)
  Empty: ░ (gray)
  Width: 40 characters
```

##### Color Coding System
```bash
CPU/Memory/Disk Colors:
  - GREEN: Usage < 70% of threshold (healthy)
  - YELLOW: 70% ≤ Usage ≤ threshold (warning)
  - RED: Usage > threshold (critical)

Process Colors:
  - RED: CPU > 50% (high usage)
  - YELLOW: 20% < CPU ≤ 50% (moderate)
  - WHITE: CPU ≤ 20% (normal)
```

#### 5. **Data Logging**

##### CSV Format (`system_metrics.csv`)
```csv
Timestamp,CPU_Usage(%),Memory_Usage(%),Disk_Usage(%),RX_KB/s,TX_KB/s,Top_Process,Top_Process_CPU
2025-02-04 14:23:15,45,67.3,82,1523,842,chrome,45.2
2025-02-04 14:23:20,48,68.1,82,1456,901,chrome,48.1
```

##### Log Format (`monitor.log`)
```
2025-02-04 14:23:15 [INFO] Starting system monitor daemon (PID: 12345)
2025-02-04 14:25:30 [ALERT] CPU usage high (85%)
2025-02-04 14:25:30 [WARN] Top CPU consumer: PID=5678 CMD=chrome CPU=82.5%
2025-02-04 14:25:30 [ACTION] Killing process: PID=5678, Info: user chrome 82.5 12.3, Reason: High CPU usage (82.5%)
2025-02-04 14:25:32 [ACTION] Process PID=5678 terminated gracefully
```

## 🛡️ Safety Features

### 1. **Protected Process List**
Prevents termination of critical system processes that could cause system instability.

**Default Protected Processes**:
- **System Core**: `systemd`, `init`
- **Shell/SSH**: `bash`, `sshd`, `ssh`
- **Containers**: `docker`, `dockerd`, `kubelet`, `kube`
- **Databases**: `mysql`, `postgres`
- **Web Servers**: `nginx`, `apache2`, `httpd`

**Customization**: Add to `PROTECTED_PROCESSES` in config file

### 2. **Kill Cooldown Mechanism**
Prevents rapid re-killing of processes that restart automatically.

- **Default Cooldown**: 60 seconds
- **Purpose**: Avoid kill loops
- **Mechanism**: Tracks PID:timestamp pairs

### 3. **Graceful Termination**
Attempts clean shutdown before force-killing.

**Process**:
1. Send SIGTERM (allows cleanup)
2. Wait 2 seconds
3. Send SIGKILL only if still running

### 4. **Double Threshold System**
Separates alerting from action-taking.

```
Alert Threshold:  CPU_THRESHOLD = 80%    → Log warning
Kill Threshold:   CPU_KILL_THRESHOLD = 95% → Take action

This 15% buffer prevents unnecessary kills
```

### 5. **Usage Verification**
Requires significant resource usage before killing.

- **CPU**: Must use >50% to be killed
- **Memory**: Must use >20% to be killed

### 6. **Manual Override**
Default configuration requires manual intervention.

```properties
AUTO_KILL_ENABLED=false  # Change to 'true' to enable auto-kill
```

## 📁 File Structure

```
system-monitor/
│
├── system_monitor.sh          # Main executable script
├── monitor_config.conf        # Configuration file
├── monitor.log               # Event and alert logs (auto-created)
├── system_metrics.csv        # Historical metrics data (auto-created)
└── README.md                 # This documentation
```

### File Purposes

| File | Purpose | Created By |
|------|---------|------------|
| `system_monitor.sh` | Main monitoring script | User (manual) |
| `monitor_config.conf` | Configuration settings | User (manual) |
| `monitor.log` | Text logs of events/alerts | Script (auto) |
| `system_metrics.csv` | Time-series metrics data | Script (auto) |

## 💡 Examples

### Example 1: Basic Dashboard Monitoring

```bash
# Start dashboard with default settings
./system_monitor.sh dashboard
```

**Output**:
```
╔══════════════════════════════════════════════════════════════════════════════╗
║                      SYSTEM RESOURCE MONITOR - DASHBOARD                     ║
╚══════════════════════════════════════════════════════════════════════════════╝

📅 Time: 2025-02-04 14:30:15
🔄 Interval: 5s | Auto-Kill: false

┌─ SYSTEM METRICS ─────────────────────────────────────────────────────────────┐

  🖥️  CPU Usage: 45% (threshold: 80%)
     [████████████████████░░░░░░░░░░░░░░░░░░░░]

  💾 Memory Usage: 67.3% (threshold: 85%)
     [███████████████████████████░░░░░░░░░░░░░]

  💿 Disk Usage: 82% (threshold: 90%)
     [████████████████████████████████░░░░░░░░]

  🌐 Network:
     ↓ RX: 1523 KB/s
     ↑ TX: 842 KB/s

└──────────────────────────────────────────────────────────────────────────────┘

┌─ TOP 10 RESOURCE-CONSUMING PROCESSES ────────────────────────────────────────┐

PID      USER       COMMAND         CPU%     MEM%    
────────────────────────────────────────────────────────────────────────────────
5678     user       chrome          45.2     12.3    
9012     user       python          23.1     8.5     
3456     root       dockerd         12.5     6.2     

└──────────────────────────────────────────────────────────────────────────────┘

Status:
  ✓ All metrics within normal range

Press Ctrl+C to exit dashboard
```

### Example 2: Daemon Mode with Custom Configuration

```bash
# Create custom config
cat > my_config.conf << EOF
CPU_THRESHOLD=70
MEM_THRESHOLD=80
AUTO_KILL_ENABLED=true
CPU_KILL_THRESHOLD=90
INTERVAL=10
EOF

# Run daemon with custom config
CONFIG_FILE=my_config.conf ./system_monitor.sh daemon &

# Check logs
tail -f monitor.log
```

### Example 3: High CPU Alert Scenario

**Scenario**: CPU usage exceeds threshold

**Configuration**:
```properties
CPU_THRESHOLD=80
AUTO_KILL_ENABLED=true
CPU_KILL_THRESHOLD=95
```

**What Happens**:
```
Time: 14:30:00 - CPU: 85%
  ├─→ Alert logged: "CPU usage high (85%)"
  ├─→ Metric recorded to CSV
  └─→ No kill (below CPU_KILL_THRESHOLD of 95%)

Time: 14:30:05 - CPU: 96%
  ├─→ Alert logged: "CPU usage high (96%)"
  ├─→ Find top CPU consumer: PID=5678 (chrome, 92%)
  ├─→ Check: Not protected ✓
  ├─→ Check: Not recently killed ✓
  ├─→ Check: CPU > 50% ✓
  ├─→ Send SIGTERM to PID 5678
  ├─→ Wait 2 seconds
  ├─→ Process terminated gracefully
  └─→ Add to kill cooldown list

Time: 14:30:10 - CPU: 45%
  └─→ Normal monitoring resumed
```

### Example 4: Protected Process Scenario

**Scenario**: Database consuming high resources

**Log Output**:
```
2025-02-04 14:35:20 [ALERT] CPU usage high (96%)
2025-02-04 14:35:20 [WARN] Top CPU consumer: PID=1234 CMD=postgres CPU=89.2%
2025-02-04 14:35:20 [WARN] Process PID=1234 (postgres) is protected, skipping kill
2025-02-04 14:35:20 [INFO] Auto-kill disabled for protected process
```

**Result**: Process is NOT killed due to protection

## 🔧 Troubleshooting

### Issue 1: "bc: command not found"

**Symptom**: Errors when comparing floating-point numbers

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install bc

# CentOS/RHEL
sudo yum install bc

# macOS
brew install bc
```

### Issue 2: Network monitoring shows "0 0"

**Cause**: Cannot detect network interface

**Solution**:
```bash
# Find your active interface
ip link show

# Manually check interface stats
cat /sys/class/net/eth0/statistics/rx_bytes
```

### Issue 3: Processes not being killed

**Causes & Solutions**:

1. **AUTO_KILL_ENABLED is false**
   ```bash
   # Edit config
   AUTO_KILL_ENABLED=true
   ```

2. **Process is protected**
   ```bash
   # Check protected list
   grep PROTECTED_PROCESSES monitor_config.conf
   
   # Remove from protected list if appropriate
   ```

3. **Usage below kill threshold**
   ```bash
   # Current: CPU_KILL_THRESHOLD=95
   # Lower threshold if needed (carefully!)
   CPU_KILL_THRESHOLD=85
   ```

4. **Process in cooldown**
   ```bash
   # Wait 60 seconds or reduce cooldown
   KILL_COOLDOWN=30
   ```

### Issue 4: Permission denied errors

**Symptom**: Cannot kill processes

**Solution**:
```bash
# Run with sudo (be cautious with AUTO_KILL_ENABLED=true)
sudo ./system_monitor.sh daemon

# Or adjust thresholds to avoid kills
AUTO_KILL_ENABLED=false
```

### Issue 5: Dashboard not updating

**Cause**: Terminal doesn't support ANSI colors

**Solution**:
```bash
# Use a different terminal or disable colors
# Modify script to remove color codes if needed

# Check terminal capabilities
echo $TERM
```

### Issue 6: CSV file growing too large

**Solution**:
```bash
# Rotate logs periodically
mv system_metrics.csv system_metrics_$(date +%Y%m%d).csv

# Or use logrotate
cat > /etc/logrotate.d/system-monitor << EOF
/path/to/system_metrics.csv {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
EOF
```

## 📊 Understanding the Metrics

### CPU Usage Interpretation

| Range | Status | Action |
|-------|--------|--------|
| 0-50% | Normal | None |
| 51-70% | Moderate | Monitor |
| 71-80% | Warning | Investigate |
| 81-95% | Alert | Review processes |
| 95%+ | Critical | Auto-kill if enabled |

### Memory Usage Interpretation

| Range | Status | Consideration |
|-------|--------|---------------|
| 0-60% | Healthy | Normal operation |
| 61-85% | Moderate | Acceptable |
| 86-95% | High | Check for leaks |
| 95%+ | Critical | Risk of OOM killer |

### Disk Usage Interpretation

| Range | Status | Action |
|-------|--------|--------|
| 0-70% | Normal | None |
| 71-90% | Warning | Plan cleanup |
| 91-95% | Critical | Clean immediately |
| 95%+ | Emergency | System may fail |

## 🔒 Security Considerations

1. **Privilege Level**
   - Running as root: Can kill any process
   - Running as user: Can only kill own processes
   - Recommendation: Use user-level for safety

2. **Auto-Kill Risks**
   - **Risk**: Could kill important user processes
   - **Mitigation**: Keep AUTO_KILL_ENABLED=false by default
   - **Best Practice**: Add critical processes to PROTECTED_PROCESSES

3. **Log File Security**
   ```bash
   # Restrict log file access
   chmod 600 monitor.log
   chmod 600 system_metrics.csv
   ```

4. **Configuration Protection**
   ```bash
   # Prevent unauthorized modifications
   chmod 644 monitor_config.conf
   chown root:root monitor_config.conf
   ```

## 📈 Performance Impact

The monitor itself uses minimal resources:

- **CPU**: <1% average
- **Memory**: ~10-20 MB
- **Disk I/O**: Minimal (writes every INTERVAL seconds)
- **Network**: None (only reads local stats)

## 🎓 Advanced Usage

### Running as System Service

Create systemd service file:

```bash
sudo nano /etc/systemd/system/system-monitor.service
```

```ini
[Unit]
Description=System Resource Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/system_monitor.sh daemon
Restart=always
User=monitor
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable system-monitor
sudo systemctl start system-monitor
sudo systemctl status system-monitor
```

### Integration with Alerting Systems

Export metrics for external monitoring:

```bash
# Parse CSV for Prometheus/Grafana
tail -1 system_metrics.csv | awk -F',' '{print "cpu_usage " $2}'

# Send alerts via email
if [ $CPU -gt 90 ]; then
    echo "High CPU: ${CPU}%" | mail -s "Alert" admin@example.com
fi
```

### Multiple Instance Monitoring

Monitor multiple systems:

```bash
# On each host
./system_monitor.sh daemon &

# Centralize CSV files
scp system_metrics.csv monitor@central:/data/host1.csv
```

## 📝 License

This script is provided as-is for educational and monitoring purposes.

## 🤝 Contributing

Improvements welcome! Consider adding:
- GPU monitoring
- Container-specific metrics
- Email/webhook alerts
- Web-based dashboard
- Historical trend analysis

## 📞 Support

For issues or questions:
1. Check log files: `monitor.log`
2. Review configuration: `monitor_config.conf`
3. Verify system requirements
4. Consult troubleshooting section

---

**Version**: 1.0  
**Last Updated**: February 2025  
**Compatibility**: Linux (Ubuntu 20.04+, CentOS 7+, Debian 10+)