# Automated Backup Solution – Backup & Recovery Guide

## 1. Introduction

This document explains the **design, usage, and recovery procedures** of the automated backup solution implemented using a Bash shell script. The solution is designed for **Linux systems** and focuses on preventing data loss through structured backups, integrity checks, and retention policies.

This guide is written for **beginners / freshers**, with clear explanations and real-world context.

---

## 2. Problem Statement (Scenario)

Servers store critical data that may be lost due to:

* Accidental deletion
* Hardware failure
* Disk corruption
* Malware or ransomware
* Human error

To mitigate these risks, an **automated backup system** is required that:

* Creates regular backups
* Saves storage space
* Ensures backup integrity
* Allows easy restoration
* Automatically removes old backups

---

## 3. Solution Overview

This backup solution provides:

* **Full, Incremental, and Differential backups**
* **Compressed archives** using `tar` and `gzip`
* **Integrity verification** using MD5 checksums
* **Retention policies** (Daily / Weekly / Monthly)
* **Interactive restore functionality**
* **Disk space validation** before backup execution

All operations are managed through a single script: `backup_manager.sh`.

---

## 4. File Structure

```
Backup_Script/
│
├── backup_manager.sh      # Main backup script
├── backup.conf            # Configuration file
├── BACKUP_GUIDE.md        # Documentation
│
└── /backups/              # Backup storage directory
    ├── 2026-02-04/
    │   ├── full_backup_2026-02-04.tar.gz
    │   ├── full_backup_2026-02-04.tar.gz.md5
    │   ├── incremental_backup_2026-02-04.tar.gz
    │   ├── incremental_backup_2026-02-04.tar.gz.md5
    │   ├── differential_backup_2026-02-04.tar.gz
    │   └── differential_backup_2026-02-04.tar.gz.md5
    │
    └── .meta/
        ├── last_full.snar
        └── last_inc.snar
```

---

## 5. Backup Types Explained

### 5.1 Full Backup

A **full backup** captures all files from the source directory.

* Largest in size
* Slowest to create
* Required as a baseline for other backup types

**Example:**

```bash
./backup_manager.sh backup full
```

**When to use:**
* First backup
* Weekly or monthly basis
* After major changes

---

### 5.2 Incremental Backup

An **incremental backup** stores only files that have changed since the **last backup** (full or incremental).

* Fast
* Uses minimal storage
* Restore requires full backup + all incrementals

**Example:**

```bash
./backup_manager.sh backup incremental
```

**When to use:**
* Daily backups
* After a full backup exists
* When storage space is limited

---

### 5.3 Differential Backup

A **differential backup** stores all changes since the **last full backup**.

* Faster restore than incremental
* Larger than incremental
* Balanced approach

**Example:**

```bash
./backup_manager.sh backup differential
```

**When to use:**
* Mid-week backups
* Balance between full and incremental
* When restore speed matters

---

## 6. Configuration File (`backup.conf`)

All operational settings are defined in `backup.conf`.

**Key parameters:**

```bash
# Source directory to back up
SOURCE_DIR="/home/username/data"

# Backup storage location
BACKUP_ROOT="/backups"

# Snapshot metadata directory
METADATA_DIR="/backups/.meta"

# Restore destination
RESTORE_DIR="/restore"

# Backup log file
LOG_FILE="/backups/backup.log"

# Minimum required free disk space (in KB)
MIN_FREE_KB=1048576   # 1GB

# Retention policy
DAILY_RETENTION=7
WEEKLY_RETENTION=4
MONTHLY_RETENTION=12
```

This separation ensures **clean, maintainable, and reusable code**.

---

## 7. Installation and Setup

### Step 1: Download Files

```bash
# Create project directory
mkdir -p ~/Backup_Script
cd ~/Backup_Script

# Copy files
# - backup_manager.sh
# - backup.conf
# - BACKUP_GUIDE.md
```

### Step 2: Set Permissions

```bash
# Make script executable
chmod +x backup_manager.sh

# Secure configuration file
chmod 600 backup.conf
```

### Step 3: Create Directories

```bash
# Create backup destination
sudo mkdir -p /backups
sudo chmod 755 /backups

# Create restore directory
sudo mkdir -p /restore
sudo chmod 755 /restore

# Create source data directory
mkdir -p ~/data
```

### Step 4: Configure Settings

```bash
# Edit configuration file
nano backup.conf

# Update SOURCE_DIR to your data location
SOURCE_DIR="/home/username/data"
```

---

## 8. Basic Usage

### Create Full Backup

```bash
./backup_manager.sh backup full
```

### Create Incremental Backup

```bash
./backup_manager.sh backup incremental
```

### Create Differential Backup

```bash
./backup_manager.sh backup differential
```

### Verify All Backups

```bash
./backup_manager.sh verify
```

### Restore from Backup

```bash
./backup_manager.sh restore
```

---

## 9. Backup Execution Workflow

**Step-by-step process:**

1. User runs the backup command
2. Script loads configuration from `backup.conf`
3. Disk space is verified (must meet minimum threshold)
4. Backup directory is created (e.g., `/backups/2026-02-04/`)
5. Data is archived and compressed using `tar` and `gzip`
6. MD5 checksum is generated for integrity verification
7. Retention policy is applied (old backups removed)
8. Operation is logged to `backup.log`

**Example log output:**

```
[2026-02-04 18:25:14] Starting full backup
[2026-02-04 18:25:14] Backup completed: /backups/2026-02-04/full_backup_2026-02-04.tar.gz
[2026-02-04 18:25:14] Applying retention policy
```

---

## 10. Integrity Verification

Each backup archive has a corresponding `.md5` file containing its checksum.

**How it works:**

1. When backup is created, MD5 checksum is calculated
2. Checksum is saved to `.md5` file
3. During verification, checksum is recalculated
4. If checksums match, backup is intact

**Verify all backups:**

```bash
./backup_manager.sh verify
```

**Expected output:**

```
/backups/2026-02-04/full_backup_2026-02-04.tar.gz: OK
/backups/2026-02-04/incremental_backup_2026-02-04.tar.gz: OK
/backups/2026-02-04/differential_backup_2026-02-04.tar.gz: OK
```

This ensures:

* No data corruption
* Safe and reliable restores
* Confidence in backup integrity

---

## 11. Restore Procedure (Step-by-Step)

### Interactive Restore

**Step 1:** Run restore mode

```bash
./backup_manager.sh restore
```

**Step 2:** Select backup date directory

```
Available backups:
1) /backups/2026-02-04
2) /backups/backup.log
#? 1
```

**Step 3:** Choose backup archive

```
Selected: /backups/2026-02-04
full_backup_2026-02-04.tar.gz
incremental_backup_2026-02-04.tar.gz
differential_backup_2026-02-04.tar.gz

Enter archive name to restore: full_backup_2026-02-04.tar.gz
```

**Step 4:** Files are restored

```
[2026-02-04 18:26:08] Restore completed to /restore
```

**Step 5:** Verify restored files

```bash
ls -la /restore/
cd /restore/home/username/data
ls -la
```

---

### Manual Restore (Without Script)

If you need to restore without the script:

```bash
# Go to restore directory
cd /restore

# Extract backup manually
sudo tar -xzf /backups/2026-02-04/full_backup_2026-02-04.tar.gz

# Check restored files
ls -la /restore/
```

---

### Restore Specific Files

You can extract only specific files from a backup:

```bash
# List files in backup
tar -tzf /backups/2026-02-04/full_backup_2026-02-04.tar.gz

# Extract specific file
cd /restore
sudo tar -xzf /backups/2026-02-04/full_backup_2026-02-04.tar.gz \
  home/username/data/important.txt

# Copy to original location
cp /restore/home/username/data/important.txt ~/data/
```

---

## 12. Retention Policy

The system enforces the following retention rules:

* **Daily backups**: Last 7 days
* **Weekly backups**: Last 4 weeks
* **Monthly backups**: Last 12 months

**Why retention policies matter:**

* Saves disk space
* Maintains compliance requirements
* Reduces operational overhead
* Prevents unlimited storage growth

**How it works:**

Old backups are automatically removed after each backup operation based on the retention settings in `backup.conf`.

**Customize retention:**

```bash
# Edit backup.conf
nano backup.conf

# Change retention values
DAILY_RETENTION=14     # Keep 14 days instead of 7
WEEKLY_RETENTION=8     # Keep 8 weeks instead of 4
MONTHLY_RETENTION=24   # Keep 24 months instead of 12
```

---

## 13. Logging

All operations are logged with timestamps to `backup.log`.

**View logs:**

```bash
# View entire log
cat /backups/backup.log

# View last 20 lines
tail -20 /backups/backup.log

# Search for errors
grep ERROR /backups/backup.log

# View today's backups
grep "$(date +%F)" /backups/backup.log
```

**Example log entries:**

```
[2026-02-04 17:44:34] Starting full backup
[2026-02-04 17:44:34] Backup completed: /backups/2026-02-04/full_backup_2026-02-04.tar.gz
[2026-02-04 17:44:34] Applying retention policy
[2026-02-04 17:45:13] Starting incremental backup
[2026-02-04 17:45:13] Backup completed: /backups/2026-02-04/incremental_backup_2026-02-04.tar.gz
```

Logs help in:

* Troubleshooting issues
* Auditing backup operations
* Monitoring backup health
* Compliance reporting

---

## 14. Disk Space Protection

Before every backup, the script checks available disk space.

**How it works:**

1. Script checks free space in backup destination
2. Compares with `MIN_FREE_KB` threshold (default: 1GB)
3. If free space is below threshold, backup **does not start**
4. Error message is logged

**Why this matters:**

* Prevents partial backups
* Avoids corrupted archives
* Protects against disk full errors
* Ensures backup reliability

**Example error:**

```
[ERROR] Not enough disk space
Required: 1024 MB, Available: 500 MB
```

**Check disk space manually:**

```bash
# Check backup destination space
df -h /backups

# Check source size
du -sh ~/data
```

---

## 15. Automation with Cron

Schedule automatic backups using cron jobs.

**Edit crontab:**

```bash
sudo crontab -e
```

**Example schedules:**

### Daily Incremental Backups

```cron
# Daily incremental backup at 1 AM
0 1 * * * /home/username/Backup_Script/backup_manager.sh backup incremental >> /var/log/backup_cron.log 2>&1
```

### Weekly Full Backups

```cron
# Weekly full backup on Sunday at 2 AM
0 2 * * 0 /home/username/Backup_Script/backup_manager.sh backup full >> /var/log/backup_cron.log 2>&1
```

### Monthly Verification

```cron
# Verify backups on 1st of month at 3 AM
0 3 1 * * /home/username/Backup_Script/backup_manager.sh verify >> /var/log/backup_verify.log 2>&1
```

### Complete Schedule Example

```cron
# Full backup: Every Sunday at 2:00 AM
0 2 * * 0 /home/username/Backup_Script/backup_manager.sh backup full

# Incremental backup: Monday-Saturday at 2:00 AM
0 2 * * 1-6 /home/username/Backup_Script/backup_manager.sh backup incremental

# Verify: First day of month at 3:00 AM
0 3 1 * * /home/username/Backup_Script/backup_manager.sh verify
```

**Monitor cron jobs:**

```bash
# View cron log
sudo tail -f /var/log/backup_cron.log

# Check if cron is running
sudo systemctl status cron
```

---

## 16. Troubleshooting

### Issue 1: Permission Denied

**Error:**
```
tar: Cannot open: Permission denied
```

**Solution:**
```bash
# Run with sudo
sudo ./backup_manager.sh backup full

# Or fix source permissions
sudo chmod -R +r ~/data
```

---

### Issue 2: Source Directory Not Found

**Error:**
```
tar: /data: Cannot stat: No such file or directory
```

**Solution:**
```bash
# Check configuration
grep SOURCE_DIR backup.conf

# Create directory
mkdir -p ~/data

# Update configuration
nano backup.conf
```

---

### Issue 3: Insufficient Disk Space

**Error:**
```
[ERROR] Not enough disk space
```

**Solution:**
```bash
# Check disk space
df -h /backups

# Delete old backups manually
find /backups -name "*.tar.gz" -mtime +30 -delete

# Reduce retention period
nano backup.conf
# Change DAILY_RETENTION=5
```

---

### Issue 4: Verification Failed

**Error:**
```
/backups/2026-02-04/full_backup_2026-02-04.tar.gz: FAILED
```

**Solution:**
```bash
# Backup may be corrupted
# Use previous backup or create new one
./backup_manager.sh backup full

# Check filesystem
sudo fsck /dev/sdX
```

---

### Issue 5: Restore Directory Empty

**Problem:** Files not appearing after restore

**Solution:**
```bash
# Check if restore directory exists
ls -la /restore/

# Verify backup contents first
tar -tzf /backups/2026-02-04/full_backup_2026-02-04.tar.gz | head -20

# Try manual extraction
cd /restore
sudo tar -xzf /backups/2026-02-04/full_backup_2026-02-04.tar.gz

# Find extracted files
find /restore -type f
```

---

## 17. Best Practices

### 1. Test Restores Regularly

```bash
# Monthly restore test
./backup_manager.sh restore
# Verify critical files are present
```

### 2. Monitor Logs

```bash
# Check for errors weekly
grep ERROR /backups/backup.log

# Review recent backups
tail -50 /backups/backup.log
```

### 3. Off-Site Backups

```bash
# Copy backups to external drive
rsync -avz /backups/ /mnt/external/backups/

# Or sync to remote server
rsync -avz /backups/ user@remote:/backup/offsite/
```

### 4. Secure Backups

```bash
# Restrict access to backup directory
sudo chmod 700 /backups

# Secure configuration file
chmod 600 backup.conf
```

### 5. Document Everything

Keep records of:
* Backup schedule
* Retention policies
* Configuration changes
* Restore procedures
* Emergency contacts

---

## 18. Understanding Backup Strategies

### Strategy 1: Basic Home User

**Schedule:**
* Full backup: Weekly (Sunday)
* Incremental backup: Daily

**Storage:** ~3-5x source size  
**Data loss risk:** Max 24 hours

---

### Strategy 2: Small Business

**Schedule:**
* Full backup: Weekly (Sunday)
* Differential backup: Mid-week (Wednesday)
* Incremental backup: Other days

**Storage:** ~5-7x source size  
**Data loss risk:** Max 12 hours

---

### Strategy 3: Critical Systems

**Schedule:**
* Full backup: Daily
* Incremental backup: Every 4 hours

**Storage:** ~10-15x source size  
**Data loss risk:** Max 4 hours

---

## 19. Command Reference

### All Available Commands

```bash
# Create backups
./backup_manager.sh backup full
./backup_manager.sh backup incremental
./backup_manager.sh backup differential

# Restore and verify
./backup_manager.sh restore
./backup_manager.sh verify

# View help
./backup_manager.sh
```

### Useful Maintenance Commands

```bash
# Check backup sizes
du -sh /backups/*

# Count backups
ls /backups/*/full*.tar.gz | wc -l

# Find oldest backup
ls -lt /backups/*/full*.tar.gz | tail -1

# List all backup dates
ls -1 /backups/ | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}'
```

---

## 20. Real-World Example

### Scenario: Daily Operations

**Monday morning:**
```bash
# Create weekly full backup
./backup_manager.sh backup full
```

**Tuesday-Saturday:**
```bash
# Daily incremental backups
./backup_manager.sh backup incremental
```

**Sunday:**
```bash
# Verify all backups
./backup_manager.sh verify

# Create new full backup
./backup_manager.sh backup full
```

**Results:**
* 7 days of backups
* Minimal storage usage
* Quick daily backups
* Reliable recovery point

---

## 21. Conclusion

This automated backup solution demonstrates:

* **Strong Linux fundamentals** - Using core tools like tar, gzip, and bash
* **Real-world backup strategies** - Full, incremental, and differential backups
* **Defensive scripting practices** - Error checking and validation
* **Operational reliability** - Logging, verification, and retention

It is suitable for **entry-level system administrators, DevOps engineers, and Linux trainees** and reflects production-ready design principles.

---

## 22. Additional Resources

### Learning Materials

* Linux command line basics
* Bash scripting fundamentals
* Cron job scheduling
* System administration concepts

### Tools Used

* `tar` - Archive creation
* `gzip` - Compression
* `md5sum` - Checksum generation
* `bash` - Shell scripting
* `cron` - Job scheduling

### Next Steps

1. Set up automated backups with cron
2. Practice restore procedures
3. Implement off-site backup copying
4. Add encryption for sensitive data
5. Create monitoring alerts

---

**Version:** 1.0.0  
**Last Updated:** February 4, 2026  
**Author:** HSF

---

**End of Guide**