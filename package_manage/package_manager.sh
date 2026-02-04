#!/bin/bash

################################################################################
# UNIFIED PACKAGE MANAGER
# 
# This script provides a unified interface for package management across
# different Linux distributions (Ubuntu/Debian and CentOS/RHEL/Fedora)
#
# For Beginners:
# - This script automatically detects your Linux distribution
# - You can use the same commands regardless of whether you have apt, yum, or dnf
# - All operations are logged for safety and troubleshooting
# - You can undo the last operation if something goes wrong
################################################################################

# Color codes for better readability in terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color (reset)

# Configuration files
LOG_FILE="/home/hsf/Noob_Dev/Day-4/package_manage/package_operations.log"
ROLLBACK_FILE="/home/hsf/Noob_Dev/Day-4/package_manage/.rollback_info"
VULN_REPORT="/home/hsf/Noob_Dev/Day-4/package_manage/vulnerability_scan.txt"

################################################################################
# FUNCTION: detect_package_manager
# Purpose: Automatically detects which package manager is available
# For Beginners: This checks your system and finds apt, yum, or dnf
################################################################################
detect_package_manager() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    else
        echo "none"
    fi
}

################################################################################
# FUNCTION: log_operation
# Purpose: Records every package operation with timestamp
# Parameters: $1 = operation type, $2 = package name, $3 = status
# For Beginners: This creates a history of everything you do
################################################################################
log_operation() {
    local operation="$1"
    local package="$2"
    local status="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] OPERATION: $operation | PACKAGE: $package | STATUS: $status" >> "$LOG_FILE"
}

################################################################################
# FUNCTION: save_rollback_info
# Purpose: Saves information needed to undo the last operation
# For Beginners: Like "Ctrl+Z" for package installations
################################################################################
save_rollback_info() {
    local operation="$1"
    local package="$2"
    local pm="$3"
    
    echo "$operation|$package|$pm|$(date '+%Y-%m-%d %H:%M:%S')" > "$ROLLBACK_FILE"
}

################################################################################
# FUNCTION: show_dependencies
# Purpose: Shows what other packages will be installed along with your package
# For Beginners: Like seeing all the parts needed to build something
################################################################################
show_dependencies() {
    local package="$1"
    local pm="$2"
    
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📦 Checking dependencies for: $package${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    
    case "$pm" in
        apt)
            echo -e "\n${GREEN}Dependencies that will be installed:${NC}"
            apt-cache depends "$package" 2>/dev/null | grep "Depends:" | sed 's/.*Depends: /  - /'
            ;;
        dnf)
            echo -e "\n${GREEN}Dependencies that will be installed:${NC}"
            dnf repoquery --requires "$package" 2>/dev/null | sed 's/^/  - /'
            ;;
        yum)
            echo -e "\n${GREEN}Dependencies that will be installed:${NC}"
            yum deplist "$package" 2>/dev/null | grep "dependency:" | awk '{print "  - " $2}' | sort -u
            ;;
    esac
    
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"
}

################################################################################
# FUNCTION: install_package
# Purpose: Installs a package with dependency preview
# For Beginners: Downloads and installs software on your system
################################################################################
install_package() {
    local package="$1"
    local pm=$(detect_package_manager)
    
    if [ "$pm" = "none" ]; then
        echo -e "${RED}❌ Error: No supported package manager found${NC}"
        log_operation "INSTALL" "$package" "FAILED - No package manager"
        return 1
    fi
    
    echo -e "${GREEN}🔍 Installing package: $package${NC}"
    echo -e "${YELLOW}Package Manager: $pm${NC}\n"
    
    # Show dependencies first
    show_dependencies "$package" "$pm"
    
    # Ask for confirmation
    read -p "Do you want to proceed with installation? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}⚠️  Installation cancelled${NC}"
        log_operation "INSTALL" "$package" "CANCELLED"
        return 0
    fi
    
    # Perform installation
    case "$pm" in
        apt)
            sudo apt update && sudo apt install -y "$package"
            ;;
        dnf)
            sudo dnf install -y "$package"
            ;;
        yum)
            sudo yum install -y "$package"
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Package installed successfully!${NC}"
        log_operation "INSTALL" "$package" "SUCCESS"
        save_rollback_info "INSTALL" "$package" "$pm"
    else
        echo -e "${RED}❌ Installation failed${NC}"
        log_operation "INSTALL" "$package" "FAILED"
        return 1
    fi
}

################################################################################
# FUNCTION: remove_package
# Purpose: Removes an installed package
# For Beginners: Uninstalls software from your system
################################################################################
remove_package() {
    local package="$1"
    local pm=$(detect_package_manager)
    
    if [ "$pm" = "none" ]; then
        echo -e "${RED}❌ Error: No supported package manager found${NC}"
        log_operation "REMOVE" "$package" "FAILED - No package manager"
        return 1
    fi
    
    echo -e "${YELLOW}🗑️  Removing package: $package${NC}"
    
    # Ask for confirmation
    read -p "Are you sure you want to remove $package? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}⚠️  Removal cancelled${NC}"
        log_operation "REMOVE" "$package" "CANCELLED"
        return 0
    fi
    
    case "$pm" in
        apt)
            sudo apt remove -y "$package"
            ;;
        dnf)
            sudo dnf remove -y "$package"
            ;;
        yum)
            sudo yum remove -y "$package"
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Package removed successfully!${NC}"
        log_operation "REMOVE" "$package" "SUCCESS"
        save_rollback_info "REMOVE" "$package" "$pm"
    else
        echo -e "${RED}❌ Removal failed${NC}"
        log_operation "REMOVE" "$package" "FAILED"
        return 1
    fi
}

################################################################################
# FUNCTION: update_packages
# Purpose: Updates the package list (catalog of available software)
# For Beginners: Refreshes the list of available software
################################################################################
update_packages() {
    local pm=$(detect_package_manager)
    
    echo -e "${BLUE}🔄 Updating package lists...${NC}"
    
    case "$pm" in
        apt)
            sudo apt update
            ;;
        dnf)
            sudo dnf check-update
            ;;
        yum)
            sudo yum check-update
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Package lists updated!${NC}"
        log_operation "UPDATE" "system" "SUCCESS"
    else
        echo -e "${YELLOW}⚠️  Update completed with warnings${NC}"
        log_operation "UPDATE" "system" "COMPLETED"
    fi
}

################################################################################
# FUNCTION: upgrade_packages
# Purpose: Upgrades all installed packages to their latest versions
# For Beginners: Updates all your installed software to newer versions
################################################################################
upgrade_packages() {
    local pm=$(detect_package_manager)
    
    echo -e "${BLUE}⬆️  Upgrading all packages...${NC}"
    
    read -p "This will upgrade all packages. Continue? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}⚠️  Upgrade cancelled${NC}"
        log_operation "UPGRADE" "all" "CANCELLED"
        return 0
    fi
    
    case "$pm" in
        apt)
            sudo apt upgrade -y
            ;;
        dnf)
            sudo dnf upgrade -y
            ;;
        yum)
            sudo yum upgrade -y
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ All packages upgraded!${NC}"
        log_operation "UPGRADE" "all" "SUCCESS"
    else
        echo -e "${RED}❌ Upgrade failed${NC}"
        log_operation "UPGRADE" "all" "FAILED"
        return 1
    fi
}

################################################################################
# FUNCTION: search_package
# Purpose: Searches for packages matching a keyword
# For Beginners: Find software by searching with keywords
################################################################################
search_package() {
    local keyword="$1"
    local pm=$(detect_package_manager)
    
    echo -e "${BLUE}🔍 Searching for packages matching: $keyword${NC}\n"
    
    case "$pm" in
        apt)
            apt-cache search "$keyword" | head -20
            ;;
        dnf)
            dnf search "$keyword" | head -20
            ;;
        yum)
            yum search "$keyword" | head -20
            ;;
    esac
    
    log_operation "SEARCH" "$keyword" "COMPLETED"
}

################################################################################
# FUNCTION: rollback_last_operation
# Purpose: Undoes the last package installation or removal
# For Beginners: Like pressing "Undo" - reverses your last action
################################################################################
rollback_last_operation() {
    if [ ! -f "$ROLLBACK_FILE" ]; then
        echo -e "${YELLOW}⚠️  No operation to rollback${NC}"
        return 1
    fi
    
    # Read rollback information
    IFS='|' read -r operation package pm timestamp < "$ROLLBACK_FILE"
    
    echo -e "${YELLOW}📋 Last operation:${NC}"
    echo -e "   Operation: $operation"
    echo -e "   Package: $package"
    echo -e "   Time: $timestamp\n"
    
    read -p "Do you want to rollback this operation? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}⚠️  Rollback cancelled${NC}"
        return 0
    fi
    
    # Perform opposite operation
    case "$operation" in
        INSTALL)
            echo -e "${BLUE}🔄 Rolling back installation (removing package)...${NC}"
            case "$pm" in
                apt) sudo apt remove -y "$package" ;;
                dnf) sudo dnf remove -y "$package" ;;
                yum) sudo yum remove -y "$package" ;;
            esac
            ;;
        REMOVE)
            echo -e "${BLUE}🔄 Rolling back removal (reinstalling package)...${NC}"
            case "$pm" in
                apt) sudo apt install -y "$package" ;;
                dnf) sudo dnf install -y "$package" ;;
                yum) sudo yum install -y "$package" ;;
            esac
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Rollback successful!${NC}"
        log_operation "ROLLBACK" "$package" "SUCCESS"
        rm -f "$ROLLBACK_FILE"
    else
        echo -e "${RED}❌ Rollback failed${NC}"
        log_operation "ROLLBACK" "$package" "FAILED"
    fi
}

################################################################################
# FUNCTION: scan_vulnerabilities
# Purpose: Scans installed packages for known security vulnerabilities
# For Beginners: Checks if your installed software has security problems
################################################################################
scan_vulnerabilities() {
    local pm=$(detect_package_manager)
    
    echo -e "${BLUE}🔒 Scanning for security vulnerabilities...${NC}\n"
    
    # Create report header
    {
        echo "════════════════════════════════════════════════════════"
        echo "       SECURITY VULNERABILITY SCAN REPORT"
        echo "════════════════════════════════════════════════════════"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Package Manager: $pm"
        echo "════════════════════════════════════════════════════════"
        echo ""
    } > "$VULN_REPORT"
    
    case "$pm" in
        apt)
            echo "Checking for security updates..." | tee -a "$VULN_REPORT"
            echo "" >> "$VULN_REPORT"
            
            # Check for security updates
            apt list --upgradable 2>/dev/null | grep -i security >> "$VULN_REPORT"
            
            # Get list of packages with available updates
            echo -e "\n--- PACKAGES WITH AVAILABLE UPDATES ---" >> "$VULN_REPORT"
            apt list --upgradable 2>/dev/null | tail -n +2 >> "$VULN_REPORT"
            ;;
            
        dnf)
            echo "Checking for security advisories..." | tee -a "$VULN_REPORT"
            echo "" >> "$VULN_REPORT"
            
            # Check for security updates
            dnf updateinfo list security 2>/dev/null >> "$VULN_REPORT"
            
            echo -e "\n--- SECURITY UPDATE DETAILS ---" >> "$VULN_REPORT"
            dnf updateinfo info security 2>/dev/null >> "$VULN_REPORT"
            ;;
            
        yum)
            echo "Checking for security updates..." | tee -a "$VULN_REPORT"
            echo "" >> "$VULN_REPORT"
            
            # Check for security updates
            yum updateinfo list security 2>/dev/null >> "$VULN_REPORT"
            
            echo -e "\n--- SECURITY UPDATE DETAILS ---" >> "$VULN_REPORT"
            yum updateinfo info security 2>/dev/null >> "$VULN_REPORT"
            ;;
    esac
    
    # Add summary
    {
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo "RECOMMENDATIONS:"
        echo "════════════════════════════════════════════════════════"
        echo "1. Review the packages listed above"
        echo "2. Run 'update' to refresh package lists"
        echo "3. Run 'upgrade' to install security updates"
        echo "4. Regularly scan for new vulnerabilities"
        echo ""
        echo "════════════════════════════════════════════════════════"
    } >> "$VULN_REPORT"
    
    echo -e "${GREEN}✅ Vulnerability scan complete!${NC}"
    echo -e "${BLUE}📄 Report saved to: $VULN_REPORT${NC}\n"
    
    # Show a preview
    head -30 "$VULN_REPORT"
    echo -e "\n${YELLOW}... (see full report in $VULN_REPORT)${NC}"
    
    log_operation "VULN_SCAN" "system" "COMPLETED"
}

################################################################################
# FUNCTION: show_help
# Purpose: Displays usage instructions and examples
# For Beginners: Your guide to using this script
################################################################################
show_help() {
    cat << 'HELP'
════════════════════════════════════════════════════════════════════
        UNIFIED PACKAGE MANAGER - HELP GUIDE
════════════════════════════════════════════════════════════════════

WHAT IS THIS?
  This script provides a simple, unified way to manage packages
  across different Linux distributions. Same commands work on
  Ubuntu, CentOS, Fedora, and other distributions!

USAGE:
  ./package_manager.sh <command> [package_name]

AVAILABLE COMMANDS:

  install <package>    Install a new package
                       Example: ./package_manager.sh install nginx

  remove <package>     Remove an installed package
                       Example: ./package_manager.sh remove nginx

  update               Update the package lists
                       Example: ./package_manager.sh update

  upgrade              Upgrade all installed packages
                       Example: ./package_manager.sh upgrade

  search <keyword>     Search for packages
                       Example: ./package_manager.sh search web

  rollback             Undo the last install/remove operation
                       Example: ./package_manager.sh rollback

  scan                 Scan for security vulnerabilities
                       Example: ./package_manager.sh scan

  log                  Show recent operations
                       Example: ./package_manager.sh log

  help                 Show this help message
                       Example: ./package_manager.sh help

BEGINNER TIPS:

  1. Always run 'update' before installing packages
  2. Use 'search' to find the exact package name
  3. Check dependencies before confirming installation
  4. Review the log file if something goes wrong
  5. Use 'rollback' if you need to undo something

FILES CREATED:
  - package_operations.log  : History of all operations
  - vulnerability_scan.txt   : Security scan results
  - .rollback_info          : Information for undo operation

SAFETY FEATURES:
  ✓ All operations are logged
  ✓ Confirmation prompts before major changes
  ✓ Dependency preview before installation
  ✓ Rollback capability for last operation
  ✓ Security vulnerability scanning

════════════════════════════════════════════════════════════════════
HELP
}

################################################################################
# FUNCTION: show_log
# Purpose: Displays recent operations from the log file
################################################################################
show_log() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}⚠️  No operations logged yet${NC}"
        return
    fi
    
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 Recent Package Operations:${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}\n"
    
    tail -20 "$LOG_FILE"
    
    echo -e "\n${YELLOW}Showing last 20 operations. Full log: $LOG_FILE${NC}"
}

################################################################################
# MAIN SCRIPT EXECUTION
# This is where the script starts when you run it
################################################################################

# Check if running with sufficient permissions for some operations
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}⚠️  Running as root. This is OK but be careful!${NC}\n"
fi

# Check command line arguments
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Error: No command specified${NC}"
    echo -e "${YELLOW}Run './package_manager.sh help' for usage information${NC}"
    exit 1
fi

# Parse and execute command
COMMAND="$1"
PACKAGE="$2"

case "$COMMAND" in
    install)
        if [ -z "$PACKAGE" ]; then
            echo -e "${RED}❌ Error: Package name required${NC}"
            echo -e "${YELLOW}Usage: ./package_manager.sh install <package_name>${NC}"
            exit 1
        fi
        install_package "$PACKAGE"
        ;;
    
    remove)
        if [ -z "$PACKAGE" ]; then
            echo -e "${RED}❌ Error: Package name required${NC}"
            echo -e "${YELLOW}Usage: ./package_manager.sh remove <package_name>${NC}"
            exit 1
        fi
        remove_package "$PACKAGE"
        ;;
    
    update)
        update_packages
        ;;
    
    upgrade)
        upgrade_packages
        ;;
    
    search)
        if [ -z "$PACKAGE" ]; then
            echo -e "${RED}❌ Error: Search keyword required${NC}"
            echo -e "${YELLOW}Usage: ./package_manager.sh search <keyword>${NC}"
            exit 1
        fi
        search_package "$PACKAGE"
        ;;
    
    rollback)
        rollback_last_operation
        ;;
    
    scan)
        scan_vulnerabilities
        ;;
    
    log)
        show_log
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        echo -e "${RED}❌ Error: Unknown command '$COMMAND'${NC}"
        echo -e "${YELLOW}Run './package_manager.sh help' for available commands${NC}"
        exit 1
        ;;
esac

exit 0