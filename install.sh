#!/bin/bash

# createNewSite Installation Script
# Version: 1.0.0
# Author: Light
# License: MIT

set -euo pipefail

# Colors for output
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly NC='\033[0m' # No Color

# Print colored output
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

print_info() {
    echo -e "${BLUE}Info: $1${NC}"
}

print_separator() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    echo ""
    printf '%*s\n' "$cols" '' | tr ' ' '-'
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Get script directory
get_script_dir() {
    dirname "$(readlink -f "${BASH_SOURCE[0]}")"
}

# Install createNewSite
install_createNewSite() {
    local script_dir
    script_dir=$(get_script_dir)
    
    print_separator
    print_info "Installing createNewSite..."
    print_separator
    
    # Create target directory
    print_info "Creating installation directory..."
    mkdir -p /usr/local/lib/createNewSite
    
    # Copy all script files
    print_info "Copying script files..."
    cp "$script_dir"/*.sh /usr/local/lib/createNewSite/
    
    # Set proper permissions
    print_info "Setting file permissions..."
    chmod +x /usr/local/lib/createNewSite/*.sh
    
    # Fix source paths in main script
    print_info "Fixing source paths in main script..."
    local main_script="/usr/local/lib/createNewSite/createNewSite.sh"
    
    # Replace SCRIPT_DIR with absolute path
    sed -i "s|source \"\$SCRIPT_DIR/config.sh\"|source \"/usr/local/lib/createNewSite/config.sh\"|g" "$main_script"
    sed -i "s|source \"\$SCRIPT_DIR/utils.sh\"|source \"/usr/local/lib/createNewSite/utils.sh\"|g" "$main_script"
    sed -i "s|source \"\$SCRIPT_DIR/validation.sh\"|source \"/usr/local/lib/createNewSite/validation.sh\"|g" "$main_script"
    sed -i "s|source \"\$SCRIPT_DIR/database.sh\"|source \"/usr/local/lib/createNewSite/database.sh\"|g" "$main_script"
    sed -i "s|source \"\$SCRIPT_DIR/apache.sh\"|source \"/usr/local/lib/createNewSite/apache.sh\"|g" "$main_script"
    sed -i "s|source \"\$SCRIPT_DIR/wordpress.sh\"|source \"/usr/local/lib/createNewSite/wordpress.sh\"|g" "$main_script"
    
    # Create wrapper script for sudo compatibility
    print_info "Creating wrapper script..."
    cat > /usr/local/bin/createNewSite << 'EOF'
#!/bin/bash
# Wrapper script for createNewSite with sudo compatibility
export PATH="/usr/local/bin:$PATH"
exec /usr/local/lib/createNewSite/createNewSite.sh "$@"
EOF
    
    # Set permissions for wrapper
    chmod +x /usr/local/bin/createNewSite
    
    # Verify installation
    print_info "Verifying installation..."
    if [[ -f "/usr/local/bin/createNewSite" ]] && [[ -f "/usr/local/lib/createNewSite/createNewSite.sh" ]]; then
        print_success "Installation completed successfully!"
    else
        print_error "Installation verification failed"
        exit 1
    fi
}

# Uninstall createNewSite
uninstall_createNewSite() {
    print_separator
    print_warning "Uninstalling createNewSite..."
    print_separator
    
    # Remove wrapper script
    if [[ -f "/usr/local/bin/createNewSite" ]]; then
        print_info "Removing wrapper script..."
        rm -f /usr/local/bin/createNewSite
    fi
    
    # Remove installation directory
    if [[ -d "/usr/local/lib/createNewSite" ]]; then
        print_info "Removing installation directory..."
        rm -rf /usr/local/lib/createNewSite
    fi
    
    print_success "Uninstallation completed successfully!"
}

# Show installation status
show_status() {
    print_separator
    print_info "createNewSite Installation Status"
    print_separator
    
    if [[ -f "/usr/local/bin/createNewSite" ]]; then
        print_success "✓ Wrapper script exists: /usr/local/bin/createNewSite"
        if [[ -x "/usr/local/bin/createNewSite" ]]; then
            echo "  → Executable: Yes"
        else
            echo "  → Executable: No"
        fi
    else
        print_error "✗ Wrapper script not found"
    fi
    
    if [[ -d "/usr/local/lib/createNewSite" ]]; then
        print_success "✓ Installation directory exists: /usr/local/lib/createNewSite"
        local file_count
        file_count=$(find /usr/local/lib/createNewSite -name "*.sh" | wc -l)
        echo "  → Contains $file_count script files"
    else
        print_error "✗ Installation directory not found"
    fi
    
    if command -v createNewSite &> /dev/null; then
        print_success "✓ Command is available in PATH"
    else
        print_error "✗ Command not found in PATH"
    fi
}

# Test installation
test_installation() {
    print_separator
    print_info "Testing installation..."
    print_separator
    
    if createNewSite --help &>/dev/null; then
        print_success "✓ Command works without sudo"
    else
        print_warning "✗ Command failed without sudo"
    fi
    
    if sudo env "PATH=$PATH" createNewSite --help &>/dev/null; then
        print_success "✓ Command works with sudo (using PATH)"
    else
        print_warning "✗ Command failed with sudo (using PATH)"
    fi
    
    if sudo /usr/local/bin/createNewSite --help &>/dev/null; then
        print_success "✓ Command works with sudo (full path)"
    else
        print_warning "✗ Command failed with sudo (full path)"
    fi
}

# Show help
show_help() {
    cat <<EOF
createNewSite Installation Script v1.0.0

DESCRIPTION:
  This script installs or uninstalls the createNewSite tool system-wide.

USAGE:
  sudo $0 [OPTIONS]

OPTIONS:
  install     Install createNewSite (default)
  uninstall   Uninstall createNewSite
  status      Show installation status
  test        Test installation
  help        Show this help message

EXAMPLES:
  sudo $0                    # Install createNewSite
  sudo $0 install           # Install createNewSite
  sudo $0 uninstall         # Uninstall createNewSite
  sudo $0 status            # Show installation status
  sudo $0 test              # Test installation

INSTALLATION LOCATIONS:
  Scripts: /usr/local/lib/createNewSite/
  Command: /usr/local/bin/createNewSite (wrapper script)

EOF
}

# Main function
main() {
    local action="${1:-install}"
    
    case "$action" in
        "install")
            check_root
            install_createNewSite
            show_status
            test_installation
            ;;
        "uninstall")
            check_root
            uninstall_createNewSite
            ;;
        "status")
            show_status
            ;;
        "test")
            test_installation
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_error "Unknown action: $action"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
