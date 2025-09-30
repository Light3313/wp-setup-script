#!/bin/bash

# createNewSite Validation Module
# Version: 1.0.0
# Author: Light
# License: MIT

# Source configuration and utilities
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Validate site name
validate_site_name() {
    local site_name="$1"
    
    if is_empty "$site_name"; then
        print_error "Site name cannot be empty"
        return 1
    fi
    
    # Trim whitespace
    site_name=$(trim "$site_name")
    
    if [[ ${#site_name} -lt $MIN_SITE_NAME_LENGTH || ${#site_name} -gt $MAX_SITE_NAME_LENGTH ]]; then
        print_error "Site name must be $MIN_SITE_NAME_LENGTH-$MAX_SITE_NAME_LENGTH characters long"
        return 1
    fi
    
    # Allow alphanumeric, hyphens, and underscores
    if [[ ! "$site_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        print_error "Site name must start with alphanumeric character and contain only letters, numbers, hyphens, and underscores"
        return 1
    fi
    
    # Check for reserved names
    for reserved in "${RESERVED_NAMES[@]}"; do
        if [[ "$site_name" == "$reserved" ]]; then
            print_error "Site name '$site_name' is reserved and cannot be used"
            return 1
        fi
    done
    
    # Check for common problematic patterns
    if [[ "$site_name" =~ ^[0-9] ]]; then
        print_warning "Site name starts with a number, which may cause issues"
    fi
    
    if [[ "$site_name" =~ _+$ ]]; then
        print_warning "Site name ends with underscores, which may cause issues"
    fi
    
    if [[ "$site_name" =~ -+$ ]]; then
        print_warning "Site name ends with hyphens, which may cause issues"
    fi
    
    return 0
}

# Validate database name
validate_database_name() {
    local db_name="$1"
    
    if is_empty "$db_name"; then
        print_error "Database name cannot be empty"
        return 1
    fi
    
    # Trim whitespace
    db_name=$(trim "$db_name")
    
    if [[ ${#db_name} -gt $MAX_DB_NAME_LENGTH ]]; then
        print_error "Database name must be $MAX_DB_NAME_LENGTH characters or less"
        return 1
    fi
    
    # MySQL naming rules
    if [[ ! "$db_name" =~ ^[a-zA-Z0-9_]+$ ]]; then
        print_error "Database name must contain only letters, numbers, and underscores"
        return 1
    fi
    
    # Check for reserved MySQL names
    local reserved_db_names=("mysql" "information_schema" "performance_schema" "sys" "test")
    for reserved in "${reserved_db_names[@]}"; do
        if [[ "$db_name" == "$reserved" ]]; then
            print_error "Database name '$db_name' is reserved by MySQL"
            return 1
        fi
    done
    
    # Check for problematic patterns
    if [[ "$db_name" =~ ^[0-9] ]]; then
        print_warning "Database name starts with a number, which may cause issues"
    fi
    
    return 0
}

# Validate username
validate_username() {
    local username="$1"
    local type="${2:-Username}"
    
    if is_empty "$username"; then
        print_error "$type cannot be empty"
        return 1
    fi
    
    # Trim whitespace
    username=$(trim "$username")
    
    if [[ ${#username} -gt $MAX_USERNAME_LENGTH ]]; then
        print_error "$type must be $MAX_USERNAME_LENGTH characters or less"
        return 1
    fi
    
    if [[ ! "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
        print_error "$type must contain only letters, numbers, and underscores"
        return 1
    fi
    
    # Check for reserved usernames
    local reserved_usernames=("root" "admin" "administrator" "mysql" "apache" "www-data")
    for reserved in "${reserved_usernames[@]}"; do
        if [[ "$username" == "$reserved" ]]; then
            print_error "$type '$username' is reserved and cannot be used"
            return 1
        fi
    done
    
    # Check for problematic patterns
    if [[ "$username" =~ ^[0-9] ]]; then
        print_warning "$type starts with a number, which may cause issues"
    fi
    
    return 0
}

# Validate password
validate_password() {
    local password="$1"
    local type="${2:-Password}"
    
    if is_empty "$password"; then
        print_error "$type cannot be empty"
        return 1
    fi
    
    if [[ ${#password} -lt $MIN_PASSWORD_LENGTH ]]; then
        print_error "$type must be at least $MIN_PASSWORD_LENGTH characters long"
        return 1
    fi
    
    # Check for very weak passwords
    if [[ "$password" =~ ^(password|1234|admin|root|mysql)$ ]]; then
        print_warning "$type is very weak and easily guessable"
    fi
    
    # Check for common patterns
    if [[ "$password" =~ ^[0-9]+$ ]]; then
        print_warning "$type contains only numbers"
    fi
    
    if [[ "$password" =~ ^[a-zA-Z]+$ ]]; then
        print_warning "$type contains only letters"
    fi
    
    return 0
}

# Validate email
validate_email() {
    local email="$1"
    
    if is_empty "$email"; then
        print_error "Email cannot be empty"
        return 1
    fi
    
    # Trim whitespace
    email=$(trim "$email")
    
    # Basic email format check
    if [[ ! "$email" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
        print_error "Invalid email format (must contain @ and domain)"
        return 1
    fi
    
    # Check for common issues
    if [[ "$email" =~ \.\. ]]; then
        print_error "Email contains consecutive dots"
        return 1
    fi
    
    if [[ "$email" =~ ^\. ]]; then
        print_error "Email cannot start with a dot"
        return 1
    fi
    
    if [[ "$email" =~ \.$ ]]; then
        print_error "Email cannot end with a dot"
        return 1
    fi
    
    # Check for valid domain
    local domain
    domain=$(echo "$email" | cut -d'@' -f2)
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_error "Invalid domain format in email"
        return 1
    fi
    
    return 0
}

# Validate file path
validate_file_path() {
    local path="$1"
    local type="${2:-Path}"
    
    if is_empty "$path"; then
        print_error "$type cannot be empty"
        return 1
    fi
    
    # Check for dangerous paths
    if [[ "$path" == "/" ]]; then
        print_error "$type cannot be root directory"
        return 1
    fi
    
    if [[ "$path" =~ ^/etc/ ]]; then
        print_error "$type cannot be in /etc directory"
        return 1
    fi
    
    if [[ "$path" =~ ^/root ]]; then
        print_error "$type cannot be in /root directory"
        return 1
    fi
    
    # Check for valid characters
    if [[ "$path" =~ [^a-zA-Z0-9/._-] ]]; then
        print_error "$type contains invalid characters"
        return 1
    fi
    
    return 0
}

# Validate port number
validate_port() {
    local port="$1"
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        print_error "Port must be a number"
        return 1
    fi
    
    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        print_error "Port must be between 1 and 65535"
        return 1
    fi
    
    # Check for reserved ports
    local reserved_ports=(22 23 25 53 80 110 143 443 993 995)
    for reserved in "${reserved_ports[@]}"; do
        if [[ $port -eq $reserved ]]; then
            print_warning "Port $port is commonly reserved for system services"
        fi
    done
    
    return 0
}

# Validate URL
validate_url() {
    local url="$1"
    
    if is_empty "$url"; then
        print_error "URL cannot be empty"
        return 1
    fi
    
    # Basic URL format check
    if [[ ! "$url" =~ ^https?:// ]]; then
        print_error "URL must start with http:// or https://"
        return 1
    fi
    
    # Check for valid characters
    if [[ "$url" =~ [^a-zA-Z0-9:/._-] ]]; then
        print_error "URL contains invalid characters"
        return 1
    fi
    
    return 0
}

# Validate all site parameters
validate_site_parameters() {
    local site_name="$1"
    local admin_name="$2"
    local admin_password="$3"
    local admin_email="$4"
    local db_name="$5"
    local db_user="$6"
    local db_password="$7"
    
    local validation_errors=0
    
    print_info "Validating site parameters..."
    
    # Validate site name
    if ! validate_site_name "$site_name"; then
        ((validation_errors++))
    fi
    
    # Validate admin username
    if ! validate_username "$admin_name" "Admin username"; then
        ((validation_errors++))
    fi
    
    # Validate admin password
    if ! validate_password "$admin_password" "Admin password"; then
        ((validation_errors++))
    fi
    
    # Validate admin email
    if ! validate_email "$admin_email"; then
        ((validation_errors++))
    fi
    
    # Validate database name
    if ! validate_database_name "$db_name"; then
        ((validation_errors++))
    fi
    
    # Validate database username
    if ! validate_username "$db_user" "Database username"; then
        ((validation_errors++))
    fi
    
    # Validate database password
    if ! validate_password "$db_password" "Database password"; then
        ((validation_errors++))
    fi
    
    # Check for parameter conflicts
    if [[ "$admin_name" == "$db_user" ]]; then
        print_warning "Admin username and database username are the same"
    fi
    
    if [[ "$admin_password" == "$db_password" ]]; then
        print_warning "Admin password and database password are the same"
    fi
    
    if [[ "$site_name" == "$db_name" ]]; then
        print_warning "Site name and database name are the same"
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        print_error "Validation failed with $validation_errors error(s)"
        return 1
    fi
    
    print_success "All parameters validated successfully"
    return 0
}

# Validate removal parameters
validate_removal_parameters() {
    local site_name="$1"
    local db_name="$2"
    local db_user="$3"
    
    local validation_errors=0
    
    print_info "Validating removal parameters..."
    
    # Validate site name
    if ! validate_site_name "$site_name"; then
        ((validation_errors++))
    fi
    
    # Validate database name
    if ! validate_database_name "$db_name"; then
        ((validation_errors++))
    fi
    
    # Validate database username
    if ! validate_username "$db_user" "Database username"; then
        ((validation_errors++))
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        print_error "Validation failed with $validation_errors error(s)"
        return 1
    fi
    
    print_success "Removal parameters validated successfully"
    return 0
}

# Check if site already exists
check_site_exists() {
    local site_name="$1"
    local site_dir="$WEB_ROOT/$site_name"
    
    if [[ -d "$site_dir" ]] && [[ -n "$(ls -A "$site_dir" 2>/dev/null)" ]]; then
        print_error "Site directory $site_dir already exists and is not empty"
        return 1
    fi
    
    if [[ -f "$APACHE_SITES_DIR/${site_name}.conf" ]]; then
        print_error "Apache configuration for $site_name already exists"
        return 1
    fi
    
    local hosts_line="127.0.0.1 ${site_name}.localhost"
    if grep -Fxq "$hosts_line" "$HOSTS_FILE" 2>/dev/null; then
        print_error "Hosts entry for ${site_name}.localhost already exists"
        return 1
    fi
    
    return 0
}

# Check if site exists for removal
check_site_exists_for_removal() {
    local site_name="$1"
    local site_dir="$WEB_ROOT/$site_name"
    
    if [[ ! -d "$site_dir" ]]; then
        print_warning "Site directory $site_dir does not exist"
    fi
    
    if [[ ! -f "$APACHE_SITES_DIR/${site_name}.conf" ]]; then
        print_warning "Apache configuration for $site_name does not exist"
    fi
    
    local hosts_line="127.0.0.1 ${site_name}.localhost"
    if ! grep -Fxq "$hosts_line" "$HOSTS_FILE" 2>/dev/null; then
        print_warning "Hosts entry for ${site_name}.localhost does not exist"
    fi
    
    return 0
}

# Validate system requirements
validate_system_requirements() {
    local errors=0
    
    print_info "Validating system requirements..."
    
    # Check disk space
    if ! check_disk_space "$WEB_ROOT" 100; then
        ((errors++))
    fi
    
    # Check if Apache is running
    if ! systemctl is-active --quiet apache2; then
        print_error "Apache2 service is not running"
        ((errors++))
    fi
    
    # Check if MySQL is running
    if ! systemctl is-active --quiet mysql && ! systemctl is-active --quiet mariadb; then
        print_error "MySQL/MariaDB service is not running"
        ((errors++))
    fi
    
    # Check Apache modules
    if ! apache2ctl -M 2>/dev/null | grep -q "rewrite_module"; then
        print_error "Apache mod_rewrite module is not enabled"
        ((errors++))
    fi
    
    # Check WP-CLI
    if ! command_exists wp; then
        print_error "WP-CLI is not installed"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        print_error "System requirements validation failed with $errors error(s)"
        return 1
    fi
    
    print_success "System requirements validated successfully"
    return 0
}

# Sanitize input
sanitize_input() {
    local input="$1"
    
    # Remove leading/trailing whitespace
    input=$(trim "$input")
    
    # Remove control characters
    input=$(echo "$input" | tr -d '\000-\037\177')
    
    echo "$input"
}

# Validate and sanitize all inputs
validate_and_sanitize_inputs() {
    local site_name="$1"
    local admin_name="$2"
    local admin_password="$3"
    local admin_email="$4"
    local db_name="$5"
    local db_user="$6"
    local db_password="$7"
    
    # Sanitize inputs
    site_name=$(sanitize_input "$site_name")
    admin_name=$(sanitize_input "$admin_name")
    admin_email=$(sanitize_input "$admin_email")
    db_name=$(sanitize_input "$db_name")
    db_user=$(sanitize_input "$db_user")
    
    # Validate sanitized inputs
    validate_site_parameters "$site_name" "$admin_name" "$admin_password" "$admin_email" "$db_name" "$db_user" "$db_password"
}

# Export all functions for use in other scripts
export -f validate_site_name validate_database_name validate_username validate_password validate_email
export -f validate_file_path validate_port validate_url validate_site_parameters validate_removal_parameters
export -f check_site_exists check_site_exists_for_removal validate_system_requirements
export -f sanitize_input validate_and_sanitize_inputs
