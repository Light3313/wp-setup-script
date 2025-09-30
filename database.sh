#!/bin/bash

# createNewSite Database Module
# Version: 1.0.0
# Author: Light
# License: MIT

# Source configuration and utilities
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Execute MySQL command using root authentication
execute_mysql() {
    local query="$1"
    local silent="${2:-false}"
    
    if [[ "$silent" == "true" ]]; then
        if ! mysql -u root -e "$query" &>/dev/null; then
            print_error "MySQL query failed: $query"
            return 1
        fi
    else
        if ! mysql -u root -e "$query" 2>/dev/null; then
            print_error "MySQL query failed: $query"
            return 1
        fi
    fi
}

# Test MySQL connection
test_mysql_connection() {
    print_info "$INFO_TESTING_MYSQL"
    
    if ! mysql -u root -e "SELECT 1;" &>/dev/null; then
        print_error "$ERROR_MYSQL_CONNECTION. Please ensure MySQL is running and accessible."
        return 1
    fi
    
    print_success "$SUCCESS_MYSQL_CONNECTION"
    return 0
}

# Check if database exists
database_exists() {
    local db_name="$1"
    
    local result
    result=$(mysql -u root -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$db_name';" 2>/dev/null | grep -c "$db_name" || echo "0")
    
    [[ $result -gt 0 ]]
}

# Check if user exists
user_exists() {
    local username="$1"
    
    local result
    result=$(mysql -u root -e "SELECT User FROM mysql.user WHERE User = '$username' AND Host = 'localhost';" 2>/dev/null | grep -c "$username" || echo "0")
    
    [[ $result -gt 0 ]]
}

# Create database
create_database() {
    local db_name="$1"
    
    print_info "$INFO_CREATING_DB '$db_name'..."
    
    if database_exists "$db_name"; then
        print_warning "Database '$db_name' already exists"
        return 0
    fi
    
    execute_mysql "CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    
    if [[ $? -eq 0 ]]; then
        print_success "Database '$db_name' created successfully"
        return 0
    else
        print_error "Failed to create database '$db_name'"
        return 1
    fi
}

# Create database user
create_database_user() {
    local username="$1"
    local password="$2"
    
    print_info "$INFO_CREATING_USER '$username'..."
    
    if user_exists "$username"; then
        print_warning "User '$username' already exists"
        return 0
    fi
    
    execute_mysql "CREATE USER IF NOT EXISTS '$username'@'localhost' IDENTIFIED BY '$password';"
    
    if [[ $? -eq 0 ]]; then
        print_success "User '$username' created successfully"
        return 0
    else
        print_error "Failed to create user '$username'"
        return 1
    fi
}

# Grant privileges to user
grant_privileges() {
    local username="$1"
    local db_name="$2"
    
    print_info "$INFO_GRANTING_PRIVILEGES..."
    
    execute_mysql "GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$username'@'localhost';"
    execute_mysql "FLUSH PRIVILEGES;"
    
    if [[ $? -eq 0 ]]; then
        print_success "Privileges granted successfully"
        return 0
    else
        print_error "Failed to grant privileges"
        return 1
    fi
}

# Setup complete database environment
setup_database() {
    local db_name="$1"
    local db_user="$2"
    local db_password="$3"
    
    # Test MySQL connection first
    if ! test_mysql_connection; then
        return 1
    fi
    
    # Create database
    if ! create_database "$db_name"; then
        return 1
    fi
    
    # Create user
    if ! create_database_user "$db_user" "$db_password"; then
        return 1
    fi
    
    # Grant privileges
    if ! grant_privileges "$db_user" "$db_name"; then
        return 1
    fi
    
    print_success "Database setup completed successfully"
    return 0
}

# Drop database
drop_database() {
    local db_name="$1"
    
    print_info "Dropping database '$db_name'..."
    
    if ! database_exists "$db_name"; then
        print_warning "Database '$db_name' does not exist"
        return 0
    fi
    
    execute_mysql "DROP DATABASE IF EXISTS \`$db_name\`;"
    
    if [[ $? -eq 0 ]]; then
        print_success "Database '$db_name' dropped successfully"
        return 0
    else
        print_error "Failed to drop database '$db_name'"
        return 1
    fi
}

# Drop database user
drop_database_user() {
    local username="$1"
    
    print_info "Dropping user '$username'..."
    
    if ! user_exists "$username"; then
        print_warning "User '$username' does not exist"
        return 0
    fi
    
    execute_mysql "DROP USER IF EXISTS '$username'@'localhost';"
    execute_mysql "FLUSH PRIVILEGES;"
    
    if [[ $? -eq 0 ]]; then
        print_success "User '$username' dropped successfully"
        return 0
    else
        print_error "Failed to drop user '$username'"
        return 1
    fi
}

# Remove complete database environment
remove_database() {
    local db_name="$1"
    local db_user="$2"
    
    # Test MySQL connection first
    if ! test_mysql_connection; then
        return 1
    fi
    
    # Drop database
    if ! drop_database "$db_name"; then
        return 1
    fi
    
    # Drop user
    if ! drop_database_user "$db_user"; then
        return 1
    fi
    
    print_success "Database removal completed successfully"
    return 0
}

# Backup database
backup_database() {
    local db_name="$1"
    local backup_file="$2"
    
    print_info "Creating database backup..."
    
    if ! database_exists "$db_name"; then
        print_error "Database '$db_name' does not exist"
        return 1
    fi
    
    if ! mysqldump -u root "$db_name" > "$backup_file" 2>/dev/null; then
        print_error "Failed to backup database '$db_name'"
        return 1
    fi
    
    print_success "Database backup created: $backup_file"
    return 0
}

# Restore database from backup
restore_database() {
    local db_name="$1"
    local backup_file="$2"
    
    print_info "Restoring database from backup..."
    
    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file '$backup_file' does not exist"
        return 1
    fi
    
    if ! mysql -u root "$db_name" < "$backup_file" 2>/dev/null; then
        print_error "Failed to restore database '$db_name'"
        return 1
    fi
    
    print_success "Database restored successfully"
    return 0
}

# Get database size
get_database_size() {
    local db_name="$1"
    
    if ! database_exists "$db_name"; then
        echo "0B"
        return 1
    fi
    
    local size_bytes
    size_bytes=$(mysql -u root -e "SELECT ROUND(SUM(data_length + index_length) / 1024, 1) AS 'DB Size in KB' FROM information_schema.tables WHERE table_schema='$db_name';" 2>/dev/null | tail -n1 | awk '{print $1}')
    
    if [[ -n "$size_bytes" && "$size_bytes" != "NULL" ]]; then
        format_bytes $((size_bytes * 1024))
    else
        echo "0B"
    fi
}

# Get database table count
get_database_table_count() {
    local db_name="$1"
    
    if ! database_exists "$db_name"; then
        echo "0"
        return 1
    fi
    
    mysql -u root -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$db_name';" 2>/dev/null | tail -n1
}

# List all databases
list_databases() {
    print_info "Available databases:"
    mysql -u root -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$" | while read -r db; do
        if [[ -n "$db" ]]; then
            local size
            size=$(get_database_size "$db")
            echo "  - $db ($size)"
        fi
    done
}

# List all users
list_users() {
    print_info "Available MySQL users:"
    mysql -u root -e "SELECT User, Host FROM mysql.user WHERE Host = 'localhost';" 2>/dev/null | grep -v -E "^(User|root|mysql.sys|mysql.session|mysql.infoschema)$" | while read -r user host; do
        if [[ -n "$user" && "$user" != "User" ]]; then
            echo "  - $user@$host"
        fi
    done
}

# Check database connection with user credentials
test_database_connection() {
    local db_name="$1"
    local db_user="$2"
    local db_password="$3"
    
    print_info "Testing database connection with user credentials..."
    
    if ! mysql -u "$db_user" -p"$db_password" -e "SELECT 1;" &>/dev/null; then
        print_error "Database connection failed with user credentials"
        return 1
    fi
    
    if ! mysql -u "$db_user" -p"$db_password" -e "USE \`$db_name\`; SELECT 1;" &>/dev/null; then
        print_error "Cannot access database '$db_name' with user credentials"
        return 1
    fi
    
    print_success "Database connection test successful"
    return 0
}

# Optimize database
optimize_database() {
    local db_name="$1"
    
    print_info "Optimizing database '$db_name'..."
    
    if ! database_exists "$db_name"; then
        print_error "Database '$db_name' does not exist"
        return 1
    fi
    
    execute_mysql "USE \`$db_name\`; OPTIMIZE TABLE $(mysql -u root -e "SELECT GROUP_CONCAT(table_name) FROM information_schema.tables WHERE table_schema='$db_name';" 2>/dev/null | tail -n1);"
    
    if [[ $? -eq 0 ]]; then
        print_success "Database optimization completed"
        return 0
    else
        print_error "Database optimization failed"
        return 1
    fi
}

# Repair database
repair_database() {
    local db_name="$1"
    
    print_info "Repairing database '$db_name'..."
    
    if ! database_exists "$db_name"; then
        print_error "Database '$db_name' does not exist"
        return 1
    fi
    
    execute_mysql "USE \`$db_name\`; REPAIR TABLE $(mysql -u root -e "SELECT GROUP_CONCAT(table_name) FROM information_schema.tables WHERE table_schema='$db_name';" 2>/dev/null | tail -n1);"
    
    if [[ $? -eq 0 ]]; then
        print_success "Database repair completed"
        return 0
    else
        print_error "Database repair failed"
        return 1
    fi
}

# Get database status
get_database_status() {
    local db_name="$1"
    
    if ! database_exists "$db_name"; then
        echo "Database '$db_name' does not exist"
        return 1
    fi
    
    local size
    size=$(get_database_size "$db_name")
    local table_count
    table_count=$(get_database_table_count "$db_name")
    
    echo "Database Status:"
    echo "  Name: $db_name"
    echo "  Size: $size"
    echo "  Tables: $table_count"
    echo "  Status: Active"
}

# Export all functions for use in other scripts
export -f execute_mysql test_mysql_connection database_exists user_exists
export -f create_database create_database_user grant_privileges setup_database
export -f drop_database drop_database_user remove_database
export -f backup_database restore_database get_database_size get_database_table_count
export -f list_databases list_users test_database_connection
export -f optimize_database repair_database get_database_status
