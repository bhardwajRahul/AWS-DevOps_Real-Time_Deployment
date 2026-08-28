#!/bin/bash

# Deployment Backup Script
# Creates a timestamped backup of current application deployment
# Lifecycle Hook: BeforeInstall (runorder: 2)

set -euo pipefail
IFS=$'\n\t'

readonly LOG_FILE="/var/log/deployment-backup.log"
readonly SOURCE_DIR="/var/www/html"
readonly BACKUP_BASE_DIR="/var/backups/devops-app"
readonly MAX_BACKUPS=5

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

rotate_backups() {
    log_info "Rotating old backups (retaining latest ${MAX_BACKUPS})..."
    if [[ -d "$BACKUP_BASE_DIR" ]]; then
        local backup_count
        backup_count=$(find "$BACKUP_BASE_DIR" -maxdepth 1 -type f -name "backup_*.tar.gz" | wc -l)
        if [[ $backup_count -gt $MAX_BACKUPS ]]; then
            find "$BACKUP_BASE_DIR" -maxdepth 1 -type f -name "backup_*.tar.gz" | sort | head -n -"$MAX_BACKUPS" | while read -r old_backup; do
                log_info "Removing old backup: $old_backup"
                rm -f "$old_backup"
            done
        fi
    fi
}

main() {
    log_info "=== DEPLOYMENT BACKUP STARTED ==="
    
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$BACKUP_BASE_DIR"
    
    if [[ -d "$SOURCE_DIR" ]] && [[ "$(ls -A "$SOURCE_DIR" 2>/dev/null)" ]]; then
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        local backup_file="${BACKUP_BASE_DIR}/backup_${timestamp}.tar.gz"
        
        log_info "Creating backup of ${SOURCE_DIR} to ${backup_file}..."
        if tar -czf "$backup_file" -C "$SOURCE_DIR" . 2>/dev/null; then
            log_info "Backup created successfully: $(du -sh "$backup_file" | cut -f1)"
            rotate_backups
        else
            log_warning "Failed to create compressed backup, continuing deployment..."
        fi
    else
        log_info "Source directory ${SOURCE_DIR} is empty or does not exist. Skipping backup."
    fi
    
    log_info "=== DEPLOYMENT BACKUP COMPLETED ==="
}

main "$@"
