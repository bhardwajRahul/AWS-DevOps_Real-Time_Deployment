#!/bin/bash

# Nginx Start Script
# This script starts and configures Nginx for the DevOps blog application
# Version: 2.0
# Author: AWS DevOps Pipeline

set -euo pipefail  # Exit on error, undefined variables, and pipe failures
IFS=$'\n\t'     # Safer IFS

# Configuration variables
readonly LOG_FILE="/var/log/nginx-start.log"
readonly LOCK_FILE="/var/lock/nginx-start.lock"
readonly MAX_RETRIES=5
readonly RETRY_DELAY=3
readonly HEALTH_CHECK_TIMEOUT=30

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
check_nginx_installation() {
    log_info "Checking Nginx installation..."
    
    if ! command -v nginx &>/dev/null; then
        log_error "Nginx is not installed. Please install it first."
        exit 1
    fi
    
    local nginx_version
    nginx_version=$(nginx -v 2>&1 | cut -d' ' -f3)
    log_info "Nginx is installed: $nginx_version"
}

# Function to acquire lock
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_error "Another start process is already running (PID: $pid)"
            exit 1
        else
            log_warning "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Function to validate Nginx configuration
validate_nginx_config() {
    log_info "Validating Nginx configuration..."
    
    if nginx -t 2>/dev/null; then
        log_info "Nginx configuration is valid"
    else
        log_error "Nginx configuration is invalid"
        log_info "Configuration test output:"
        nginx -t 2>&1 | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Function to start Nginx with enhanced retry logic
start_nginx_service() {
    log_info "Starting Nginx service..."
    
    # Enable Nginx to start on boot
    if systemctl enable nginx; then
        log_info "Nginx service enabled on boot"
    else
        log_warning "Failed to enable Nginx service on boot"
    fi
    
    # Start Nginx service with retry logic
    local start_success=false
    for attempt in $(seq 1 $MAX_RETRIES); do
        log_info "Attempt $attempt/$MAX_RETRIES: Starting Nginx..."
        
        if systemctl start nginx; then
            log_info "Nginx start command executed successfully"
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
    
    if [[ "$start_success" = false ]]; then
        log_error "All Nginx start attempts failed"
        exit 1
    fi
}

# Function to verify Nginx is running
verify_nginx_running() {
    log_info "Verifying Nginx is running..."
    
    # Wait for service to fully start
    sleep 3
    
    # Check if Nginx is active
    local is_active=false
    for i in {1..10}; do
        if systemctl is-active --quiet nginx; then
            is_active=true
            break
        else
            log_info "Waiting for Nginx to become active... ($i/10)"
            sleep 1
        fi
    done
    
    if [[ "$is_active" = true ]]; then
        log_info "Nginx is running successfully"
    else
        log_error "Nginx is not running"
        log_info "Nginx status:"
        systemctl status nginx --no-pager | tee -a "$LOG_FILE"
        exit 1
    fi
    
    # Check if Nginx is listening on expected ports
    local listening_ports
    listening_ports=$(netstat -tlnp 2>/dev/null | grep nginx | wc -l)
    
    if [[ $listening_ports -gt 0 ]]; then
        log_info "Nginx is listening on $listening_ports port(s)"
        netstat -tlnp 2>/dev/null | grep nginx | sed 's/^/  /' | tee -a "$LOG_FILE"
    else
        log_warning "Nginx is not listening on any ports"
    fi
}

# Function to test HTTP response with timeout
test_http_response() {
    log_info "Testing HTTP response..."
    
    # Wait a bit more for Nginx to be fully ready
    sleep 3
    
    # Test HTTP response with timeout
    local http_success=false
    for attempt in $(seq 1 5); do
        log_info "HTTP test attempt $attempt/5"
        
        if timeout 10 curl -s -f http://localhost > /dev/null 2>&1; then
            log_info "HTTP response test passed"
            http_success=true
            break
        else
            log_warning "HTTP test attempt $attempt failed"
            if [[ $attempt -lt 5 ]]; then
                sleep 2
            fi
        fi
    done
    
    if [[ "$http_success" = false ]]; then
        log_warning "HTTP response test failed (this may be normal if no content is deployed yet)"
        
        # Additional diagnostic information
        log_info "Running diagnostic checks..."
        if command -v curl &>/dev/null; then
            log_info "Testing with curl verbose:"
            timeout 5 curl -v http://localhost 2>&1 | head -20 | tee -a "$LOG_FILE" || true
        fi
    fi
}

# Function to display comprehensive Nginx status
display_nginx_status() {
    log_info "=== NGINX STATUS SUMMARY ==="
    
    # Service status
    log_info "Service Status: $(systemctl is-active nginx)"
    log_info "Service State: $(systemctl is-enabled nginx)"
    
    # Process information
    log_info "Process Information:"
    ps aux | grep nginx | grep -v grep | sed 's/^/  /' | tee -a "$LOG_FILE" || log_warning "No nginx processes found"
    
    # Port status
    log_info "Port Status:"
    netstat -tlnp 2>/dev/null | grep nginx | sed 's/^/  /' | tee -a "$LOG_FILE" || log_warning "No nginx ports found"
    
    # Configuration test
    log_info "Configuration Test:"
    if nginx -t 2>/dev/null; then
        log_info "  PASSED"
    else
        log_error "  FAILED"
    fi
    
    # Memory usage
    log_info "Memory Usage:"
    local nginx_memory
    nginx_memory=$(ps aux | grep nginx | grep -v grep | awk '{sum+=$6} END {print sum/1024 "MB"}' 2>/dev/null || echo "N/A")
    log_info "  Total: $nginx_memory"
    
    # Uptime information
    log_info "Service Uptime:"
    systemctl show nginx --property=ActiveEnterTimestamp | cut -d= -f2 | tee -a "$LOG_FILE" || log_warning "Could not get uptime info"
}

# Main execution
main() {
    log_info "=== NGINX START SCRIPT STARTED ==="
    log_info "Script version: 2.0"
    log_info "Running as: $(whoami)"
    log_info "System: $(uname -a)"
    
    acquire_lock
    check_nginx_installation
    validate_nginx_config
    start_nginx_service
    verify_nginx_running
    test_http_response
    display_nginx_status
    
    log_info "Nginx started successfully!"
    log_info "=== NGINX START SCRIPT COMPLETED ==="
}

# Run main function
main "$@"
