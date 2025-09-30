#!/bin/bash

# createNewSite Apache Module
# Version: 1.0.0
# Author: Light
# License: MIT

# Source configuration and utilities
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Test Apache configuration
test_apache_config() {
    print_info "$INFO_TESTING_APACHE"
    
    if ! apachectl configtest &>/dev/null; then
        print_error "$ERROR_APACHE_CONFIG"
        return 1
    fi
    
    print_success "Apache configuration test passed"
    return 0
}

# Reload Apache
reload_apache() {
    print_info "$INFO_RELOADING_APACHE"
    
    if ! systemctl reload apache2 &>/dev/null; then
        print_error "Failed to reload Apache"
        return 1
    fi
    
    print_success "Apache reloaded successfully"
    return 0
}

# Restart Apache
restart_apache() {
    print_info "Restarting Apache..."
    
    if ! systemctl restart apache2 &>/dev/null; then
        print_error "Failed to restart Apache"
        return 1
    fi
    
    print_success "Apache restarted successfully"
    return 0
}

# Check if Apache site is enabled
is_site_enabled() {
    local site_name="$1"
    
    [[ -L "$APACHE_ENABLED_DIR/${site_name}.conf" ]]
}

# Enable Apache site
enable_apache_site() {
    local site_name="$1"
    
    print_info "$INFO_ENABLING_SITE"
    
    if is_site_enabled "$site_name"; then
        print_warning "Site '$site_name' is already enabled"
        return 0
    fi
    
    if ! a2ensite "${site_name}.conf" &>/dev/null; then
        print_error "Failed to enable site '$site_name'"
        return 1
    fi
    
    print_success "Site '$site_name' enabled successfully"
    return 0
}

# Disable Apache site
disable_apache_site() {
    local site_name="$1"
    
    print_info "Disabling Apache site..."
    
    if ! is_site_enabled "$site_name"; then
        print_warning "Site '$site_name' is not enabled"
        return 0
    fi
    
    if ! a2dissite "${site_name}.conf" &>/dev/null; then
        print_error "Failed to disable site '$site_name'"
        return 1
    fi
    
    print_success "Site '$site_name' disabled successfully"
    return 0
}

# Create Apache virtual host configuration
create_apache_config() {
    local site_name="$1"
    local site_dir="$2"
    
    local apache_conf="$APACHE_SITES_DIR/${site_name}.conf"
    
    print_info "$INFO_CREATING_APACHE_CONFIG"
    
    # Backup existing config if it exists
    if [[ -f "$apache_conf" ]]; then
        backup_file "$apache_conf"
    fi
    
    # Create configuration using template
    local config_content="$APACHE_CONFIG_TEMPLATE"
    config_content="${config_content//\{SITE_NAME\}/$site_name}"
    config_content="${config_content//\{SITE_DIR\}/$site_dir}"
    config_content="${config_content//\{APACHE_LOG_DIR\}/$APACHE_LOG_DIR}"
    
    echo "$config_content" > "$apache_conf"
    
    if [[ $? -eq 0 ]]; then
        print_success "Apache configuration created: $apache_conf"
        return 0
    else
        print_error "Failed to create Apache configuration"
        return 1
    fi
}

# Remove Apache virtual host configuration
remove_apache_config() {
    local site_name="$1"
    
    local apache_conf="$APACHE_SITES_DIR/${site_name}.conf"
    
    print_info "Removing Apache configuration..."
    
    if [[ -f "$apache_conf" ]]; then
        rm -f "$apache_conf"
        print_success "Apache configuration removed: $apache_conf"
    else
        print_warning "Apache configuration file does not exist: $apache_conf"
    fi
    
    return 0
}

# Update hosts file
update_hosts_file() {
    local site_name="$1"
    local action="$2"  # add or remove
    
    local hosts_line="127.0.0.1 ${site_name}.localhost"
    
    if [[ "$action" == "add" ]]; then
        if ! grep -Fxq "$hosts_line" "$HOSTS_FILE" 2>/dev/null; then
            print_info "$INFO_UPDATING_HOSTS"
            
            # Backup hosts file
            backup_file "$HOSTS_FILE"
            
            local tmpfile
            tmpfile=$(create_temp_file "hosts")
            
            # Add the new entry at the beginning
            echo "$hosts_line" > "$tmpfile"
            cat "$HOSTS_FILE" >> "$tmpfile"
            
            cp "$tmpfile" "$HOSTS_FILE"
            rm -f "$tmpfile"
            
            print_success "Hosts entry added: $hosts_line"
        else
            print_info "Hosts entry already exists: $hosts_line"
        fi
    elif [[ "$action" == "remove" ]]; then
        if grep -Fxq "$hosts_line" "$HOSTS_FILE" 2>/dev/null; then
            print_info "Removing hosts entry..."
            
            # Backup hosts file
            backup_file "$HOSTS_FILE"
            
            local tmpfile
            tmpfile=$(create_temp_file "hosts")
            
            grep -Fxv "$hosts_line" "$HOSTS_FILE" > "$tmpfile"
            cp "$tmpfile" "$HOSTS_FILE"
            rm -f "$tmpfile"
            
            print_success "Hosts entry removed: $hosts_line"
        else
            print_info "Hosts entry does not exist: $hosts_line"
        fi
    fi
    
    return 0
}

# Create WordPress .htaccess file
create_htaccess() {
    local site_dir="$1"
    
    print_info "$INFO_CREATING_HTACCESS"
    
    local htaccess_file="$site_dir/.htaccess"
    
    # Backup existing .htaccess if it exists
    if [[ -f "$htaccess_file" ]]; then
        backup_file "$htaccess_file"
    fi
    
    echo "$HTACCESS_TEMPLATE" > "$htaccess_file"
    
    if [[ $? -eq 0 ]]; then
        set_file_permissions "$htaccess_file" "$HTACCESS_PERMISSIONS"
        print_success "WordPress .htaccess file created"
        return 0
    else
        print_error "Failed to create .htaccess file"
        return 1
    fi
}

# Remove .htaccess file
remove_htaccess() {
    local site_dir="$1"
    
    local htaccess_file="$site_dir/.htaccess"
    
    if [[ -f "$htaccess_file" ]]; then
        rm -f "$htaccess_file"
        print_success ".htaccess file removed"
    else
        print_warning ".htaccess file does not exist"
    fi
    
    return 0
}

# Check Apache status
check_apache_status() {
    print_info "Checking Apache status..."
    
    if systemctl is-active --quiet apache2; then
        print_success "Apache2 service is running"
    else
        print_error "Apache2 service is not running"
        return 1
    fi
    
    if systemctl is-enabled --quiet apache2; then
        print_success "Apache2 service is enabled"
    else
        print_warning "Apache2 service is not enabled"
    fi
    
    return 0
}

# List enabled Apache sites
list_enabled_sites() {
    print_info "Enabled Apache sites:"
    
    if [[ -d "$APACHE_ENABLED_DIR" ]]; then
        ls -1 "$APACHE_ENABLED_DIR"/*.conf 2>/dev/null | while read -r conf_file; do
            if [[ -f "$conf_file" ]]; then
                local site_name
                site_name=$(basename "$conf_file" .conf)
                echo "  - $site_name"
            fi
        done
    else
        print_warning "Apache enabled sites directory does not exist"
    fi
}

# List available Apache sites
list_available_sites() {
    print_info "Available Apache sites:"
    
    if [[ -d "$APACHE_SITES_DIR" ]]; then
        ls -1 "$APACHE_SITES_DIR"/*.conf 2>/dev/null | while read -r conf_file; do
            if [[ -f "$conf_file" ]]; then
                local site_name
                site_name=$(basename "$conf_file" .conf)
                local status="disabled"
                
                if is_site_enabled "$site_name"; then
                    status="enabled"
                fi
                
                echo "  - $site_name ($status)"
            fi
        done
    else
        print_warning "Apache sites directory does not exist"
    fi
}

# Get Apache version
get_apache_version() {
    apache2 -v 2>/dev/null | head -n1 | sed 's/Apache\/\([0-9.]*\).*/\1/'
}

# Get Apache modules
get_apache_modules() {
    print_info "Loaded Apache modules:"
    apache2ctl -M 2>/dev/null | grep -E "^\s*[a-zA-Z_]+_module" | while read -r module; do
        echo "  - $module"
    done
}

# Check if Apache module is loaded
is_apache_module_loaded() {
    local module="$1"
    
    apache2ctl -M 2>/dev/null | grep -q "${module}_module"
}

# Enable Apache module
enable_apache_module() {
    local module="$1"
    
    print_info "Enabling Apache module: $module"
    
    if is_apache_module_loaded "$module"; then
        print_warning "Module '$module' is already enabled"
        return 0
    fi
    
    if ! a2enmod "$module" &>/dev/null; then
        print_error "Failed to enable module '$module'"
        return 1
    fi
    
    print_success "Module '$module' enabled successfully"
    return 0
}

# Disable Apache module
disable_apache_module() {
    local module="$1"
    
    print_info "Disabling Apache module: $module"
    
    if ! is_apache_module_loaded "$module"; then
        print_warning "Module '$module' is not enabled"
        return 0
    fi
    
    if ! a2dismod "$module" &>/dev/null; then
        print_error "Failed to disable module '$module'"
        return 1
    fi
    
    print_success "Module '$module' disabled successfully"
    return 0
}

# Get Apache error log
get_apache_error_log() {
    local site_name="$1"
    local lines="${2:-50}"
    
    local error_log="$APACHE_LOG_DIR/${site_name}_error.log"
    
    if [[ -f "$error_log" ]]; then
        print_info "Last $lines lines of Apache error log for $site_name:"
        tail -n "$lines" "$error_log"
    else
        print_warning "Apache error log not found: $error_log"
    fi
}

# Get Apache access log
get_apache_access_log() {
    local site_name="$1"
    local lines="${2:-50}"
    
    local access_log="$APACHE_LOG_DIR/${site_name}_access.log"
    
    if [[ -f "$access_log" ]]; then
        print_info "Last $lines lines of Apache access log for $site_name:"
        tail -n "$lines" "$access_log"
    else
        print_warning "Apache access log not found: $access_log"
    fi
}

# Clear Apache logs
clear_apache_logs() {
    local site_name="$1"
    
    local error_log="$APACHE_LOG_DIR/${site_name}_error.log"
    local access_log="$APACHE_LOG_DIR/${site_name}_access.log"
    
    print_info "Clearing Apache logs for $site_name..."
    
    if [[ -f "$error_log" ]]; then
        > "$error_log"
        print_success "Error log cleared"
    fi
    
    if [[ -f "$access_log" ]]; then
        > "$access_log"
        print_success "Access log cleared"
    fi
}

# Setup complete Apache environment for site
setup_apache_site() {
    local site_name="$1"
    local site_dir="$2"
    
    # Create Apache configuration
    if ! create_apache_config "$site_name" "$site_dir"; then
        return 1
    fi
    
    # Test Apache configuration
    if ! test_apache_config; then
        return 1
    fi
    
    # Enable site
    if ! enable_apache_site "$site_name"; then
        return 1
    fi
    
    # Reload Apache
    if ! reload_apache; then
        return 1
    fi
    
    # Update hosts file
    if ! update_hosts_file "$site_name" "add"; then
        return 1
    fi
    
    print_success "Apache site setup completed successfully"
    return 0
}

# Remove complete Apache environment for site
remove_apache_site() {
    local site_name="$1"
    
    # Disable site
    if ! disable_apache_site "$site_name"; then
        return 1
    fi
    
    # Remove configuration
    if ! remove_apache_config "$site_name"; then
        return 1
    fi
    
    # Update hosts file
    if ! update_hosts_file "$site_name" "remove"; then
        return 1
    fi
    
    # Test Apache configuration
    if ! test_apache_config; then
        return 1
    fi
    
    # Reload Apache
    if ! reload_apache; then
        return 1
    fi
    
    print_success "Apache site removal completed successfully"
    return 0
}

# Export all functions for use in other scripts
export -f test_apache_config reload_apache restart_apache
export -f is_site_enabled enable_apache_site disable_apache_site
export -f create_apache_config remove_apache_config update_hosts_file
export -f create_htaccess remove_htaccess check_apache_status
export -f list_enabled_sites list_available_sites get_apache_version get_apache_modules
export -f is_apache_module_loaded enable_apache_module disable_apache_module
export -f get_apache_error_log get_apache_access_log clear_apache_logs
export -f setup_apache_site remove_apache_site
