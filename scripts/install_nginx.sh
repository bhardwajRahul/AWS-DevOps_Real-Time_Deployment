#!/bin/bash

# Nginx Installation Script
# This script installs and configures Nginx for the DevOps blog application
# Version: 2.0
# Author: AWS DevOps Pipeline

set -euo pipefail  # Exit on error, undefined variables, and pipe failures
IFS=$'\n\t'     # Safer IFS

# Configuration variables
readonly NGINX_VERSION="nginx"
readonly LOG_FILE="/var/log/nginx-install.log"
readonly LOCK_FILE="/var/lock/nginx-install.lock"
readonly MAX_RETRIES=3
readonly RETRY_DELAY=5

# Function to log messages with timestamp and level
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Function to log info messages
log_info() {
    log_message "INFO" "$1"
}

# Function to log warning messages
log_warning() {
    log_message "WARNING" "$1"
}

# Function to log error messages
log_error() {
    log_message "ERROR" "$1"
}

# Function to cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
    fi
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script failed with exit code $exit_code"
    fi
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Function to check if Nginx is installed
is_nginx_installed() {
    dpkg -l | grep -qw nginx 2>/dev/null
}

# Function to acquire lock
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_error "Another installation is already running (PID: $pid)"
            exit 1
        else
            log_warning "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Function to check system requirements
check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check available disk space (minimum 500MB)
    local available_space
    available_space=$(df / | tail -1 | awk '{print $4}')
    local min_space_kb=500000  # 500MB in KB
    
    if [[ $available_space -lt $min_space_kb ]]; then
        local available_mb=$((available_space / 1024))
        local required_mb=$((min_space_kb / 1024))
        log_error "Insufficient disk space (${available_mb}MB available, ${required_mb}MB required)"
        exit 1
    fi
    
    # Check if running on supported OS
    if ! command -v apt-get &> /dev/null; then
        log_error "This script requires a Debian/Ubuntu-based system"
        exit 1
    fi
    
    # Check system architecture
    local arch=$(uname -m)
    if [[ ! "$arch" =~ ^(x86_64|aarch64|arm64)$ ]]; then
        log_warning "Unsupported architecture: $arch (proceeding anyway)"
    fi
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root. Use sudo."
        exit 1
    fi
    
    log_info "System requirements check passed"
}

# Function to install Nginx with retry logic
install_nginx() {
    log_info "=== NGINX INSTALLATION STARTED ==="
    
    # Update package lists with retry
    local update_success=false
    for attempt in $(seq 1 $MAX_RETRIES); do
        log_info "Updating package lists (attempt $attempt/$MAX_RETRIES)..."
        if apt-get update -y; then
            update_success=true
            break
        else
            log_warning "Package update attempt $attempt failed"
            if [[ $attempt -eq $MAX_RETRIES ]]; then
                log_error "Failed to update package lists after $MAX_RETRIES attempts"
                exit 1
            fi
            sleep $RETRY_DELAY
        fi
    done
    
    if [[ "$update_success" = true ]]; then
        log_info "Package lists updated successfully"
    fi
    
    # Install Nginx if not already installed
    if is_nginx_installed; then
        log_info "Nginx is already installed"
        nginx -v 2>&1 | sed 's/^/  /' | tee -a "$LOG_FILE"
    else
        log_info "Installing Nginx..."
        
        local install_success=false
        for attempt in $(seq 1 $MAX_RETRIES); do
            log_info "Installation attempt $attempt/$MAX_RETRIES"
            if apt-get install -y nginx; then
                install_success=true
                break
            else
                log_warning "Nginx installation attempt $attempt failed"
                if [[ $attempt -eq $MAX_RETRIES ]]; then
                    log_error "Failed to install Nginx after $MAX_RETRIES attempts"
                    exit 1
                fi
                sleep $RETRY_DELAY
            fi
        done
        
        # Verify installation
        if is_nginx_installed; then
            log_info "Nginx installed successfully"
            nginx -v 2>&1 | sed 's/^/  /' | tee -a "$LOG_FILE"
        else
            log_error "Nginx installation verification failed"
            exit 1
        fi
    fi
}

# Function to configure and start Nginx
configure_nginx() {
    log_info "Configuring Nginx..."
    
    # Enable Nginx service
    if systemctl enable nginx; then
        log_info "Nginx service enabled on boot"
    else
        log_warning "Failed to enable Nginx service on boot"
    fi
    
    # Start Nginx service
    log_info "Starting Nginx service..."
    local start_success=false
    for attempt in $(seq 1 $MAX_RETRIES); do
        if systemctl start nginx; then
            start_success=true
            break
        else
            log_warning "Nginx start attempt $attempt failed"
            if [[ $attempt -eq $MAX_RETRIES ]]; then
                log_error "Failed to start Nginx after $MAX_RETRIES attempts"
                systemctl status nginx --no-pager | tee -a "$LOG_FILE"
                exit 1
            fi
            sleep $RETRY_DELAY
        fi
    done
    
    if [[ "$start_success" = true ]]; then
        log_info "Nginx start command executed successfully"
    fi
    
    # Wait for service to start
    sleep 3
    
    # Check Nginx status
    if systemctl is-active --quiet nginx; then
        log_info "Nginx is running successfully"
    else
        log_error "Nginx failed to start"
        log_info "Nginx status:"
        systemctl status nginx --no-pager | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Function to validate Nginx configuration
validate_nginx_config() {
    log_info "Validating Nginx configuration..."
    
    if nginx -t 2>/dev/null; then
        log_info "Nginx configuration is valid"
    else
        log_error "Nginx configuration is invalid"
        nginx -t 2>&1 | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Function to display installation summary
display_summary() {
    log_info "=== INSTALLATION SUMMARY ==="
    log_info "Nginx version: $(nginx -v 2>&1 | cut -d' ' -f3)"
    log_info "Service status: $(systemctl is-active nginx)"
    log_info "Service enabled: $(systemctl is-enabled nginx)"
    log_info "Configuration test: PASSED"
    
    # Check if listening on ports
    if netstat -tlnp 2>/dev/null | grep -q "nginx"; then
        log_info "Nginx is listening on:"
        netstat -tlnp 2>/dev/null | grep nginx | sed 's/^/  /' | tee -a "$LOG_FILE"
    else
        log_warning "Nginx is not listening on any ports"
    fi
}

# Main execution
main() {
    log_info "=== NGINX INSTALLATION SCRIPT STARTED ==="
    log_info "Script version: 2.0"
    log_info "Running as: $(whoami)"
    log_info "System: $(uname -a)"
    
    acquire_lock
    check_system_requirements
    install_nginx
    validate_nginx_config
    configure_nginx
    display_summary
    
    log_info "Nginx installation and configuration completed successfully!"
    log_info "=== NGINX INSTALLATION SCRIPT COMPLETED ==="
}

# Run main function
main "$@"
