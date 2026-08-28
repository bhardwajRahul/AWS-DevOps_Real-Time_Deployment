#!/bin/bash

# Environment Validation Script
# Validates system requirements, resources, and dependencies before deployment
# Lifecycle Hook: BeforeInstall (runorder: 1)

set -euo pipefail
IFS=$'\n\t'

readonly LOG_FILE="/var/log/environment-validation.log"
readonly MIN_DISK_SPACE_KB=300000 # ~300MB in KB
readonly MIN_MEMORY_MB=256        # 256MB minimum free/available

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log_message "INFO" "$1"
}

log_warning() {
    log_message "WARNING" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

check_privileges() {
    log_info "Verifying root privileges..."
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (or via CodeDeploy root runas)."
        exit 1
    fi
    log_info "✅ Running with administrative privileges."
}

check_system_info() {
    log_info "=== SYSTEM INFORMATION ==="
    log_info "Kernel: $(uname -r)"
    log_info "Architecture: $(uname -m)"
    log_info "Hostname: $(hostname)"
    if command -v uptime &>/dev/null; then
        log_info "Uptime: $(uptime)"
    fi
}

check_disk_space() {
    log_info "Checking available storage space..."
    local available_kb
    available_kb=$(df -k / | awk 'NR==2 {print $4}')
    local available_mb=$((available_kb / 1024))
    
    log_info "Available disk space on root filesystem: ${available_mb}MB"
    
    if [[ $available_kb -lt $MIN_DISK_SPACE_KB ]]; then
        log_error "Insufficient disk space: ${available_mb}MB available, minimum required is $((MIN_DISK_SPACE_KB / 1024))MB"
        exit 1
    fi
    log_info "✅ Disk space requirement met."
}

check_memory() {
    log_info "Checking system memory..."
    if command -v free &>/dev/null; then
        local available_mb
        # free -m column 7 is 'available' on modern linux
        available_mb=$(free -m | awk 'NR==2 {if (NF>=7) print $7; else print $4}')
        log_info "Available memory: ${available_mb}MB"
        
        if [[ $available_mb -lt $MIN_MEMORY_MB ]]; then
            log_warning "Low available memory (${available_mb}MB). Deployment will proceed, but monitor resources."
        else
            log_info "✅ Memory requirement met."
        fi
    fi
}

check_required_tools() {
    log_info "Checking required utilities..."
    local required_tools=("curl" "tar" "gzip")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            log_info "✅ Found tool: $tool"
        else
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_info "Attempting to install missing tools: ${missing_tools[*]}..."
        if command -v apt-get &>/dev/null; then
            apt-get update -y && apt-get install -y "${missing_tools[@]}" || true
        elif command -v dnf &>/dev/null; then
            dnf install -y "${missing_tools[@]}" || true
        elif command -v yum &>/dev/null; then
            yum install -y "${missing_tools[@]}" || true
        fi
    fi
}

check_network_connectivity() {
    log_info "Checking network connectivity..."
    
    # Use HTTP request instead of ICMP ping because ICMP is often blocked in EC2 security groups
    if curl -s --connect-timeout 5 -I https://aws.amazon.com &>/dev/null || curl -s --connect-timeout 5 -I https://github.com &>/dev/null; then
        log_info "✅ Outbound HTTPS connectivity verified."
    else
        log_warning "Outbound internet access check timed out or is restricted (may be in private VPC)."
    fi
}

check_web_directory() {
    log_info "Checking destination directory /var/www/html..."
    mkdir -p /var/www/html
    if [[ -w /var/www/html ]]; then
        log_info "✅ Destination directory is writable."
    else
        log_warning "Correcting permissions on /var/www/html..."
        chmod 755 /var/www/html
    fi
}

main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    log_info "=== ENVIRONMENT VALIDATION STARTED ==="
    
    check_privileges
    check_system_info
    check_disk_space
    check_memory
    check_required_tools
    check_network_connectivity
    check_web_directory
    
    log_info "=== ENVIRONMENT VALIDATION COMPLETED SUCCESSFULLY ==="
}

main "$@"
