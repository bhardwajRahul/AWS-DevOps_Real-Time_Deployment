#!/bin/bash

# Nginx Installation Script
# Installs, hardens, and configures Nginx for Ubuntu/Debian and Amazon Linux
# Lifecycle Hook: AfterInstall (runorder: 1)

set -euo pipefail
IFS=$'\n\t'

# Configuration variables
readonly LOG_FILE="/var/log/nginx-install.log"
readonly LOCK_FILE="/var/lock/nginx-install.lock"
readonly MAX_RETRIES=3
readonly RETRY_DELAY=5

export DEBIAN_FRONTEND=noninteractive

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

cleanup() {
    local exit_code=$?
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
    fi
    if [[ $exit_code -ne 0 ]]; then
        log_error "Nginx installation failed with exit code $exit_code"
    fi
}

trap cleanup EXIT INT TERM

acquire_lock() {
    mkdir -p "$(dirname "$LOCK_FILE")" "$(dirname "$LOG_FILE")"
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_error "Another installation process is active (PID: $pid)"
            exit 1
        else
            log_warning "Clearing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

is_nginx_installed() {
    command -v nginx &>/dev/null
}

wait_for_apt_lock() {
    if command -v apt-get &>/dev/null; then
        local timeout=60
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
            log_info "Waiting for other package management processes to finish..."
            sleep 3
            timeout=$((timeout - 3))
            if [[ $timeout -le 0 ]]; then
                log_warning "Timed out waiting for apt lock, attempting to continue..."
                break
            fi
        done
    fi
}

install_nginx() {
    log_info "Checking current Nginx installation..."
    
    if is_nginx_installed; then
        log_info "Nginx is already installed: $(nginx -v 2>&1)"
        return 0
    fi
    
    log_info "Installing Nginx..."
    local install_success=false

    for attempt in $(seq 1 $MAX_RETRIES); do
        log_info "Package installation attempt $attempt of $MAX_RETRIES..."
        
        if command -v apt-get &>/dev/null; then
            wait_for_apt_lock
            apt-get update -y && apt-get install -y --no-install-recommends nginx curl ca-certificates && install_success=true && break
        elif command -v dnf &>/dev/null; then
            dnf install -y nginx curl && install_success=true && break
        elif command -v yum &>/dev/null; then
            yum install -y nginx curl && install_success=true && break
        else
            log_error "Unsupported package manager. Please install Nginx manually."
            exit 1
        fi
        
        log_warning "Installation attempt $attempt failed, retrying in ${RETRY_DELAY}s..."
        sleep "$RETRY_DELAY"
    done

    if [[ "$install_success" != true ]]; then
        log_error "Failed to install Nginx after $MAX_RETRIES attempts"
        exit 1
    fi

    log_info "Nginx installed successfully: $(nginx -v 2>&1)"
}

configure_nginx_service() {
    log_info "Configuring Nginx service..."
    
    # Create required directories if missing
    mkdir -p /var/www/html /etc/nginx/conf.d /var/log/nginx
    
    if command -v systemctl &>/dev/null; then
        systemctl enable nginx || log_warning "Could not enable Nginx service on boot"
    elif command -v chkconfig &>/dev/null; then
        chkconfig nginx on || true
    fi
}

main() {
    log_info "=== NGINX INSTALLATION HOOK STARTED ==="
    log_info "Host: $(uname -a)"
    
    acquire_lock
    install_nginx
    configure_nginx_service
    
    log_info "=== NGINX INSTALLATION HOOK COMPLETED ==="
}

main "$@"
