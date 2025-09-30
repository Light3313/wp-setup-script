#!/bin/bash

# createNewSite WordPress Module
# Version: 1.0.0
# Author: Light
# License: MIT

# Source configuration and utilities
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Check if WP-CLI is available
check_wp_cli() {
    if ! command_exists wp; then
        print_error "WP-CLI is not installed or not in PATH"
        return 1
    fi
    
    print_success "WP-CLI is available"
    return 0
}

# Download WordPress core
download_wordpress() {
    local site_dir="$1"
    
    print_info "$INFO_DOWNLOADING_WP"
    
    if ! wp core download --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to download WordPress"
        return 1
    fi
    
    print_success "WordPress downloaded successfully"
    return 0
}

# Create WordPress configuration
create_wp_config() {
    local site_dir="$1"
    local db_name="$2"
    local db_user="$3"
    local db_password="$4"
    
    print_info "$INFO_CREATING_CONFIG"
    
    if ! wp config create \
        --dbname="$db_name" \
        --dbuser="$db_user" \
        --dbpass="$db_password" \
        --path="$site_dir" \
        --allow-root \
        --extra-php <<PHP
$WP_EXTRA_PHP
PHP
    then
        print_error "Failed to create WordPress configuration"
        return 1
    fi
    
    print_success "WordPress configuration created"
    return 0
}

# Install WordPress
install_wordpress() {
    local site_dir="$1"
    local site_url="$2"
    local site_title="$3"
    local admin_user="$4"
    local admin_password="$5"
    local admin_email="$6"
    
    print_info "$INFO_INSTALLING_WP"
    
    if ! wp core install \
        --url="$site_url" \
        --title="$site_title" \
        --admin_user="$admin_user" \
        --admin_password="$admin_password" \
        --admin_email="$admin_email" \
        --path="$site_dir" \
        --allow-root &>/dev/null
    then
        print_error "Failed to install WordPress"
        return 1
    fi
    
    print_success "WordPress installed successfully"
    return 0
}

# Update WordPress URLs
update_wp_urls() {
    local site_dir="$1"
    local site_url="$2"
    
    print_info "Updating WordPress URLs..."
    
    if ! wp option update home "$site_url" --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to update home URL"
        return 1
    fi
    
    if ! wp option update siteurl "$site_url" --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to update site URL"
        return 1
    fi
    
    print_success "WordPress URLs updated successfully"
    return 0
}

# Set WordPress file permissions
set_wp_permissions() {
    local site_dir="$1"
    
    print_info "$INFO_SETTING_PERMISSIONS"
    
    # Set ownership
    chown -R www-data:www-data "$site_dir" 2>/dev/null || true
    
    # Set directory permissions
    find "$site_dir" -type d -exec chmod "$DEFAULT_DIR_PERMISSIONS" {} \; 2>/dev/null || true
    
    # Set file permissions
    find "$site_dir" -type f -exec chmod "$DEFAULT_FILE_PERMISSIONS" {} \; 2>/dev/null || true
    
    # Set wp-config.php permissions
    if [[ -f "$site_dir/wp-config.php" ]]; then
        chmod "$WP_CONFIG_PERMISSIONS" "$site_dir/wp-config.php" 2>/dev/null || true
    fi
    
    print_success "WordPress file permissions set"
    return 0
}

# Get WordPress version
get_wp_version() {
    local site_dir="$1"
    
    if [[ -d "$site_dir" ]]; then
        wp core version --path="$site_dir" --allow-root 2>/dev/null || echo "Unknown"
    else
        echo "Site directory does not exist"
    fi
}

# Check WordPress installation
check_wp_installation() {
    local site_dir="$1"
    
    if [[ ! -d "$site_dir" ]]; then
        print_error "Site directory does not exist: $site_dir"
        return 1
    fi
    
    if [[ ! -f "$site_dir/wp-config.php" ]]; then
        print_error "WordPress configuration file not found"
        return 1
    fi
    
    if [[ ! -f "$site_dir/wp-load.php" ]]; then
        print_error "WordPress core files not found"
        return 1
    fi
    
    print_success "WordPress installation verified"
    return 0
}

# Update WordPress core
update_wp_core() {
    local site_dir="$1"
    
    print_info "Updating WordPress core..."
    
    if ! wp core update --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to update WordPress core"
        return 1
    fi
    
    print_success "WordPress core updated successfully"
    return 0
}

# Update WordPress database
update_wp_database() {
    local site_dir="$1"
    
    print_info "Updating WordPress database..."
    
    if ! wp core update-db --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to update WordPress database"
        return 1
    fi
    
    print_success "WordPress database updated successfully"
    return 0
}

# Install WordPress plugin
install_wp_plugin() {
    local site_dir="$1"
    local plugin_name="$2"
    local activate="${3:-true}"
    
    print_info "Installing WordPress plugin: $plugin_name"
    
    if ! wp plugin install "$plugin_name" --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to install plugin: $plugin_name"
        return 1
    fi
    
    if [[ "$activate" == "true" ]]; then
        if ! wp plugin activate "$plugin_name" --path="$site_dir" --allow-root &>/dev/null; then
            print_error "Failed to activate plugin: $plugin_name"
            return 1
        fi
        print_success "Plugin installed and activated: $plugin_name"
    else
        print_success "Plugin installed: $plugin_name"
    fi
    
    return 0
}

# Uninstall WordPress plugin
uninstall_wp_plugin() {
    local site_dir="$1"
    local plugin_name="$2"
    
    print_info "Uninstalling WordPress plugin: $plugin_name"
    
    if ! wp plugin uninstall "$plugin_name" --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to uninstall plugin: $plugin_name"
        return 1
    fi
    
    print_success "Plugin uninstalled: $plugin_name"
    return 0
}

# Install WordPress theme
install_wp_theme() {
    local site_dir="$1"
    local theme_name="$2"
    local activate="${3:-false}"
    
    print_info "Installing WordPress theme: $theme_name"
    
    if ! wp theme install "$theme_name" --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to install theme: $theme_name"
        return 1
    fi
    
    if [[ "$activate" == "true" ]]; then
        if ! wp theme activate "$theme_name" --path="$site_dir" --allow-root &>/dev/null; then
            print_error "Failed to activate theme: $theme_name"
            return 1
        fi
        print_success "Theme installed and activated: $theme_name"
    else
        print_success "Theme installed: $theme_name"
    fi
    
    return 0
}

# List WordPress plugins
list_wp_plugins() {
    local site_dir="$1"
    
    print_info "WordPress plugins:"
    wp plugin list --path="$site_dir" --allow-root 2>/dev/null | while read -r line; do
        if [[ "$line" != "name"* ]]; then
            echo "  - $line"
        fi
    done
}

# List WordPress themes
list_wp_themes() {
    local site_dir="$1"
    
    print_info "WordPress themes:"
    wp theme list --path="$site_dir" --allow-root 2>/dev/null | while read -r line; do
        if [[ "$line" != "name"* ]]; then
            echo "  - $line"
        fi
    done
}

# Get WordPress site info
get_wp_site_info() {
    local site_dir="$1"
    
    print_info "WordPress site information:"
    
    local version
    version=$(get_wp_version "$site_dir")
    echo "  Version: $version"
    
    local site_url
    site_url=$(wp option get home --path="$site_dir" --allow-root 2>/dev/null || echo "Unknown")
    echo "  Site URL: $site_url"
    
    local admin_email
    admin_email=$(wp option get admin_email --path="$site_dir" --allow-root 2>/dev/null || echo "Unknown")
    echo "  Admin Email: $admin_email"
    
    local site_title
    site_title=$(wp option get blogname --path="$site_dir" --allow-root 2>/dev/null || echo "Unknown")
    echo "  Site Title: $site_title"
}

# Create WordPress admin user
create_wp_admin_user() {
    local site_dir="$1"
    local username="$2"
    local password="$3"
    local email="$4"
    local role="${5:-administrator}"
    
    print_info "Creating WordPress admin user: $username"
    
    if ! wp user create "$username" "$email" --user_pass="$password" --role="$role" --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to create WordPress admin user"
        return 1
    fi
    
    print_success "WordPress admin user created: $username"
    return 0
}

# Delete WordPress admin user
delete_wp_admin_user() {
    local site_dir="$1"
    local username="$2"
    
    print_info "Deleting WordPress admin user: $username"
    
    if ! wp user delete "$username" --yes --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to delete WordPress admin user"
        return 1
    fi
    
    print_success "WordPress admin user deleted: $username"
    return 0
}

# Reset WordPress admin password
reset_wp_admin_password() {
    local site_dir="$1"
    local username="$2"
    local new_password="$3"
    
    print_info "Resetting WordPress admin password for: $username"
    
    if ! wp user update "$username" --user_pass="$new_password" --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to reset WordPress admin password"
        return 1
    fi
    
    print_success "WordPress admin password reset for: $username"
    return 0
}

# Export WordPress database
export_wp_database() {
    local site_dir="$1"
    local export_file="$2"
    
    print_info "Exporting WordPress database..."
    
    if ! wp db export "$export_file" --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to export WordPress database"
        return 1
    fi
    
    print_success "WordPress database exported: $export_file"
    return 0
}

# Import WordPress database
import_wp_database() {
    local site_dir="$1"
    local import_file="$2"
    
    print_info "Importing WordPress database..."
    
    if ! wp db import "$import_file" --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to import WordPress database"
        return 1
    fi
    
    print_success "WordPress database imported: $import_file"
    return 0
}

# Search and replace URLs in WordPress
search_replace_wp_urls() {
    local site_dir="$1"
    local old_url="$2"
    local new_url="$3"
    
    print_info "Searching and replacing URLs in WordPress..."
    
    if ! wp search-replace "$old_url" "$new_url" --path="$site_dir" --allow-root &>/dev/null; then
        print_error "Failed to search and replace URLs"
        return 1
    fi
    
    print_success "URLs replaced successfully"
    return 0
}

# Setup complete WordPress installation
setup_wordpress() {
    local site_dir="$1"
    local site_url="$2"
    local site_title="$3"
    local admin_user="$4"
    local admin_password="$5"
    local admin_email="$6"
    local db_name="$7"
    local db_user="$8"
    local db_password="$9"
    
    # Check WP-CLI
    if ! check_wp_cli; then
        return 1
    fi
    
    # Download WordPress
    if ! download_wordpress "$site_dir"; then
        return 1
    fi
    
    # Create configuration
    if ! create_wp_config "$site_dir" "$db_name" "$db_user" "$db_password"; then
        return 1
    fi
    
    # Install WordPress
    if ! install_wordpress "$site_dir" "$site_url" "$site_title" "$admin_user" "$admin_password" "$admin_email"; then
        return 1
    fi
    
    # Update URLs
    if ! update_wp_urls "$site_dir" "$site_url"; then
        return 1
    fi
    
    # Set permissions
    if ! set_wp_permissions "$site_dir"; then
        return 1
    fi
    
    print_success "WordPress setup completed successfully"
    return 0
}

# Remove WordPress installation
remove_wordpress() {
    local site_dir="$1"
    
    print_info "Removing WordPress installation..."
    
    if [[ -d "$site_dir" ]]; then
        rm -rf "$site_dir"
        print_success "WordPress installation removed"
    else
        print_warning "WordPress installation directory does not exist"
    fi
    
    return 0
}

# Export all functions for use in other scripts
export -f check_wp_cli download_wordpress create_wp_config install_wordpress
export -f update_wp_urls set_wp_permissions get_wp_version check_wp_installation
export -f update_wp_core update_wp_database install_wp_plugin uninstall_wp_plugin
export -f install_wp_theme list_wp_plugins list_wp_themes get_wp_site_info
export -f create_wp_admin_user delete_wp_admin_user reset_wp_admin_password
export -f export_wp_database import_wp_database search_replace_wp_urls
export -f setup_wordpress remove_wordpress
