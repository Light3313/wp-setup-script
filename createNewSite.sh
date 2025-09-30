#!/bin/bash

# createNewSite - Automated WordPress Site Creator/Remover
# Version: 1.0.0
# Author: Light
# License: MIT

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/validation.sh"
source "$SCRIPT_DIR/database.sh"
source "$SCRIPT_DIR/apache.sh"
source "$SCRIPT_DIR/wordpress.sh"

# Global variables for cleanup
SITE_NAME=""
SITE_DIR=""
DB_NAME=""
DB_USER=""
CLEANUP_NEEDED=false

# Cleanup function for error handling
cleanup_on_error() {
    if [[ "$CLEANUP_NEEDED" == true ]]; then
        print_warning "$WARNING_CLEANUP"
        
        # Remove Apache config
        if [[ -n "$SITE_NAME" ]] && [[ -f "$APACHE_SITES_DIR/${SITE_NAME}.conf" ]]; then
            disable_apache_site "$SITE_NAME" &>/dev/null || true
            remove_apache_config "$SITE_NAME" &>/dev/null || true
        fi
        
        # Remove site directory
        if [[ -n "$SITE_DIR" ]] && [[ -d "$SITE_DIR" ]]; then
            rm -rf "$SITE_DIR"
        fi
        
        # Remove hosts entry
        if [[ -n "$SITE_NAME" ]]; then
            update_hosts_file "$SITE_NAME" "remove" &>/dev/null || true
        fi
        
        # Remove database
        if [[ -n "$DB_NAME" ]] && [[ -n "$DB_USER" ]]; then
            remove_database "$DB_NAME" "$DB_USER" &>/dev/null || true
        fi
        
        reload_apache &>/dev/null || true
    fi
}

# Set up error handling
trap cleanup_on_error ERR EXIT

# Create new WordPress site
create_site() {
    local site_name="$1"
    local admin_name="$2"
    local admin_password="$3"
    local admin_email="$4"
    local db_name="$5"
    local db_user="$6"
    local db_password="$7"
    
    # Set global variables for cleanup
    SITE_NAME="$site_name"
    SITE_DIR="$WEB_ROOT/$site_name"
    DB_NAME="$db_name"
    DB_USER="$db_user"
    CLEANUP_NEEDED=true
    
    # Validate inputs
    if ! validate_and_sanitize_inputs "$site_name" "$admin_name" "$admin_password" "$admin_email" "$db_name" "$db_user" "$db_password"; then
        return 1
    fi
    
    # Check if site already exists
    if ! check_site_exists "$site_name"; then
        return 1
    fi
    
    # Validate system requirements
    if ! validate_system_requirements; then
        return 1
    fi
    
    print_separator
    print_info "$INFO_CREATING_SITE: $site_name"
    print_info "Site will be created at: $SITE_DIR"
    print_info "Access URL: http://${site_name}.localhost"
    print_separator
    
    # Create site directory
    print_info "Creating site directory..."
    mkdir -p "$SITE_DIR"
    set_directory_permissions "$SITE_DIR"
    
    # Setup database
    if ! setup_database "$db_name" "$db_user" "$db_password"; then
        return 1
    fi
    
    # Setup WordPress
    local site_url="http://${site_name}.localhost"
    if ! setup_wordpress "$SITE_DIR" "$site_url" "$site_name" "$admin_name" "$admin_password" "$admin_email" "$db_name" "$db_user" "$db_password"; then
        return 1
    fi
    
    # Create .htaccess
    if ! create_htaccess "$SITE_DIR"; then
        return 1
    fi
    
    # Setup Apache
    if ! setup_apache_site "$site_name" "$SITE_DIR"; then
        return 1
    fi
    
    # Set final permissions
    set_directory_permissions "$SITE_DIR"
    
    # Disable cleanup on success
    CLEANUP_NEEDED=false
    
    print_separator
    print_success "$SUCCESS_SITE_CREATED: '$site_name'"
    print_info "Do not forget to update permalinks in the WordPress admin panel"
    echo ""
    echo "Site Details:"
    echo "  Site directory: $SITE_DIR"
    echo "  Access URL: http://${site_name}.localhost"
    echo "  Admin user: $admin_name"
    echo "  Database: $db_name"
    echo "  Database user: $db_user"
    echo ""
    echo "Security Notes:"
    echo "  - .htaccess rules applied"
    echo "  - Proper file permissions set"
    print_separator
}

# Remove WordPress site
remove_site() {
    local site_name="$1"
    local db_name="$2"
    local db_user="$3"
    
    # Validate inputs
    if ! validate_removal_parameters "$site_name" "$db_name" "$db_user"; then
        return 1
    fi
    
    local site_dir="$WEB_ROOT/$site_name"
    
    # Safety checks
    if [[ -z "$site_name" ]] || [[ "$site_dir" == "$WEB_ROOT/" ]] || [[ "$site_dir" == "/" ]]; then
        print_error "Refusing to delete $site_dir. Invalid or missing site name."
        return 1
    fi
    
    # Check if site exists for removal
    check_site_exists_for_removal "$site_name"
    
    print_separator
    print_warning "$WARNING_DESTRUCTIVE"
    echo ""
    echo "You are about to permanently delete the WordPress site: $site_name"
    echo ""
    echo "This will remove:"
    echo "  - Site directory: $site_dir"
    echo "  - Apache configuration: $APACHE_SITES_DIR/${site_name}.conf"
    echo "  - Database: $db_name"
    echo "  - Database user: $db_user"
    echo "  - Hosts file entry: 127.0.0.1 ${site_name}.localhost"
    echo ""
    echo -e "${RED}$WARNING_CANNOT_UNDO${NC}"
    print_separator
    
    # Double confirmation
    if ! confirm_action "Are you sure you want to continue?"; then
        echo "Operation cancelled."
        return 0
    fi
    
    print_separator
    print_info "$INFO_REMOVING_SITE: $site_name"
    
    # Remove Apache configuration
    if ! remove_apache_site "$site_name"; then
        return 1
    fi
    
    # Remove site directory
    if ! remove_wordpress "$site_dir"; then
        return 1
    fi
    
    # Remove database and user
    if ! remove_database "$db_name" "$db_user"; then
        return 1
    fi
    
    print_separator
    print_success "$SUCCESS_SITE_REMOVED: $site_name"
    print_separator
}

# Show site information
show_site_info() {
    local site_name="$1"
    local site_dir="$WEB_ROOT/$site_name"
    
    if [[ ! -d "$site_dir" ]]; then
        print_error "Site directory does not exist: $site_dir"
        return 1
    fi
    
    print_separator
    print_header "Site Information: $site_name"
    print_separator
    
    # Basic site info
    echo "Site Details:"
    echo "  Directory: $site_dir"
    echo "  URL: http://${site_name}.localhost"
    echo "  Size: $(get_directory_size "$site_dir")"
    echo "  Files: $(count_files "$site_dir")"
    echo "  Directories: $(count_directories "$site_dir")"
    echo ""
    
    # Apache status
    echo "Apache Status:"
    if is_site_enabled "$site_name"; then
        echo "  Status: Enabled"
    else
        echo "  Status: Disabled"
    fi
    
    if [[ -f "$APACHE_SITES_DIR/${site_name}.conf" ]]; then
        echo "  Configuration: Present"
    else
        echo "  Configuration: Missing"
    fi
    echo ""
    
    # WordPress info
    if check_wp_installation "$site_dir"; then
        get_wp_site_info "$site_dir"
    else
        echo "WordPress: Not installed or corrupted"
    fi
    echo ""
    
    # Database info (if we can determine it)
    local wp_config="$site_dir/wp-config.php"
    if [[ -f "$wp_config" ]]; then
        local db_name
        db_name=$(grep "DB_NAME" "$wp_config" | cut -d"'" -f4 2>/dev/null || echo "Unknown")
        if [[ "$db_name" != "Unknown" ]]; then
            echo "Database:"
            echo "  Name: $db_name"
            echo "  Size: $(get_database_size "$db_name")"
            echo "  Tables: $(get_database_table_count "$db_name")"
        fi
    fi
    
    print_separator
}

# List all sites
list_sites() {
    print_separator
    print_header "Available Sites"
    print_separator
    
    if [[ -d "$WEB_ROOT" ]]; then
        local sites_found=false
        
        for site_dir in "$WEB_ROOT"/*; do
            if [[ -d "$site_dir" ]]; then
                local site_name
                site_name=$(basename "$site_dir")
                
                if [[ -f "$site_dir/wp-config.php" ]]; then
                    echo "  ✓ $site_name (WordPress)"
                    sites_found=true
                else
                    echo "  - $site_name (Directory only)"
                    sites_found=true
                fi
            fi
        done
        
        if [[ "$sites_found" == false ]]; then
            print_info "No sites found in $WEB_ROOT"
        fi
    else
        print_error "Web root directory does not exist: $WEB_ROOT"
    fi
    
    echo ""
    list_enabled_sites
    print_separator
}

# Show system status
show_system_status() {
    print_separator
    print_header "System Status"
    print_separator
    
    # System information
    get_system_info
    echo ""
    
    # Apache status
    check_apache_status
    echo ""
    
    # MySQL status
    if test_mysql_connection; then
        echo "MySQL: Running"
    else
        echo "MySQL: Not running or not accessible"
    fi
    echo ""
    
    # WP-CLI status
    if check_wp_cli; then
        echo "WP-CLI: Available"
    else
        echo "WP-CLI: Not available"
    fi
    echo ""
    
    # Disk space
    echo "Disk Space:"
    df -h "$WEB_ROOT" 2>/dev/null || echo "  Unable to check disk space"
    echo ""
    
    # Apache modules
    get_apache_modules
    echo ""
    
    # Available sites
    list_available_sites
    print_separator
}

# Main function
main() {
    # Check for help or no arguments
    if [[ $# -eq 0 ]] || [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # Check root privileges
    check_root
    
    # Check dependencies
    check_dependencies
    
    # Handle different commands
    case "${1:-}" in
        "-rm"|"--remove")
            if [[ $# -ne 4 ]]; then
                print_error "Usage: $SCRIPT_NAME -rm <site-name> <db-name> <db-user>"
                exit 1
            fi
            remove_site "$2" "$3" "$4"
            ;;
        "-info"|"--info")
            if [[ $# -ne 2 ]]; then
                print_error "Usage: $SCRIPT_NAME -info <site-name>"
                exit 1
            fi
            show_site_info "$2"
            ;;
        "-list"|"--list")
            list_sites
            ;;
        "-status"|"--status")
            show_system_status
            ;;
        *)
            # Handle creation
            if [[ $# -ne 7 ]]; then
                echo ""
                echo -e "${YELLOW}For help, run: $SCRIPT_NAME --help${NC}"
                echo ""
                print_error "Usage: $SCRIPT_NAME <site-name> <admin-name> <admin-password> <admin-email> <db-name> <db-user> <db-password>"
                exit 1
            fi
            create_site "$1" "$2" "$3" "$4" "$5" "$6" "$7"
            ;;
    esac
}

# Disable cleanup trap and run main
trap - ERR EXIT
main "$@"