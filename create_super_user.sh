#!/bin/bash

#===============================================================================
# Ubuntu Super User Creator - English Version
# Description: Interactive script to create and manage super users on Ubuntu
# Author: System Administrator
# Version: 2.0
# Date: $(date +%Y-%m-%d)
#===============================================================================

#===============================================================================
# COLOR DEFINITIONS
# Define color codes for terminal output formatting
#===============================================================================
RED='\033[0;31m'        # Red color for errors
GREEN='\033[0;32m'      # Green color for success messages
YELLOW='\033[1;33m'     # Yellow color for warnings
BLUE='\033[0;34m'       # Blue color for information
PURPLE='\033[0;35m'     # Purple color for headers
CYAN='\033[0;36m'       # Cyan color for highlights
NC='\033[0m'            # No Color - reset to default

#===============================================================================
# UTILITY FUNCTIONS
# Functions for colored output and messaging
#===============================================================================

# Function to print informational messages
print_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print headers with purple color
print_header() {
    echo -e "${PURPLE}$1${NC}"
}

# Function to print highlighted text
print_highlight() {
    echo -e "${CYAN}$1${NC}"
}

#===============================================================================
# VALIDATION FUNCTIONS
# Functions to validate user input and system requirements
#===============================================================================

# Function to check if script is running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root!"
        print_message "Please run: sudo $0"
        exit 1
    fi
}

# Function to validate username format and requirements
validate_username() {
    local username=$1
    
    # Check if username is empty
    if [[ -z "$username" ]]; then
        print_error "Username cannot be empty!"
        return 1
    fi
    
    # Check if username contains only valid characters
    if [[ ! "$username" =~ ^[a-z][-a-z0-9_]*$ ]]; then
        print_error "Invalid username! Requirements:"
        print_error "- Must start with lowercase letter"
        print_error "- Can contain only lowercase letters, numbers, hyphens, and underscores"
        print_error "- Must be between 3 and 32 characters"
        return 1
    fi
    
    # Check username length
    if [[ ${#username} -lt 3 || ${#username} -gt 32 ]]; then
        print_error "Username must be between 3 and 32 characters!"
        return 1
    fi
    
    # Check if user already exists
    if id "$username" &>/dev/null; then
        print_error "User '$username' already exists!"
        return 1
    fi
    
    return 0
}

# Function to validate password strength
validate_password() {
    local password=$1
    
    # Check if password is empty
    if [[ -z "$password" ]]; then
        print_error "Password cannot be empty!"
        return 1
    fi
    
    # Check minimum password length
    if [[ ${#password} -lt 8 ]]; then
        print_error "Password must be at least 8 characters long!"
        return 1
    fi
    
    # Check password complexity (recommendations)
    if [[ ! "$password" =~ [A-Z] ]]; then
        print_warning "Recommendation: Password should contain at least one uppercase letter"
    fi
    
    if [[ ! "$password" =~ [a-z] ]]; then
        print_warning "Recommendation: Password should contain at least one lowercase letter"
    fi
    
    if [[ ! "$password" =~ [0-9] ]]; then
        print_warning "Recommendation: Password should contain at least one number"
    fi
    
    if [[ ! "$password" =~ [^a-zA-Z0-9] ]]; then
        print_warning "Recommendation: Password should contain at least one special character"
    fi
    
    return 0
}

#===============================================================================
# PASSWORD MANAGEMENT FUNCTIONS
# Functions for secure password input and confirmation
#===============================================================================

# Function to securely get and confirm password
get_password() {
    local password
    local password_confirm
    
    while true; do
        # Get password (hidden input)
        read -sp "Enter password for the user: " password
        echo
        
        # Validate password
        validate_password "$password"
        if [[ $? -eq 0 ]]; then
            break
        fi
    done
    
    # Confirm password
    while true; do
        read -sp "Confirm password: " password_confirm
        echo
        
        if [[ "$password" != "$password_confirm" ]]; then
            print_error "Passwords do not match! Please try again."
        else
            break
        fi
    done
    
    echo "$password"
}

# Function to change user password
change_user_password() {
    print_header "=== CHANGE USER PASSWORD ==="
    echo
    
    # List existing users (excluding system users)
    print_message "Available users:"
    awk -F: '$3 >= 1000 && $3 != 65534 {print "  - " $1}' /etc/passwd
    echo
    
    # Get username
    read -p "Enter username to change password: " username
    
    # Validate user exists
    if ! id "$username" &>/dev/null; then
        print_error "User '$username' does not exist!"
        return 1
    fi
    
    # Get new password
    print_message "Setting new password for user '$username'"
    password=$(get_password)
    
    # Change password
    echo "$username:$password" | chpasswd
    if [[ $? -eq 0 ]]; then
        print_success "Password changed successfully for user '$username'!"
        
        # Log the password change
        echo "$(date): Password changed for user $username" >> /var/log/user_management.log
    else
        print_error "Failed to change password!"
        return 1
    fi
}

#===============================================================================
# USER CREATION FUNCTIONS
# Functions for creating and configuring super users
#===============================================================================

# Function to create a new super user
create_super_user() {
    print_header "=== UBUNTU SUPER USER CREATOR ==="
    echo
    
    # Get username with validation
    while true; do
        read -p "Enter the new username: " username
        validate_username "$username"
        if [[ $? -eq 0 ]]; then
            break
        fi
    done
    
    # Get password
    password=$(get_password)
    
    # Get optional additional information
    read -p "Enter full name (optional): " full_name
    read -p "Enter phone number (optional): " phone_number
    read -p "Enter email address (optional): " email
    
    # Create the user
    print_message "Creating user '$username'..."
    
    # Create user with additional information if provided
    if [[ -n "$full_name" ]]; then
        useradd -m -c "$full_name" -s /bin/bash "$username"
    else
        useradd -m -s /bin/bash "$username"
    fi
    
    # Check if user creation was successful
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create user!"
        exit 1
    fi
    
    # Set password
    echo "$username:$password" | chpasswd
    if [[ $? -ne 0 ]]; then
        print_error "Failed to set password!"
        userdel -r "$username" 2>/dev/null
        exit 1
    fi
    
    # Add user to administrative groups
    print_message "Adding user to administrative groups..."
    
    # Common groups for super user privileges
    usermod -aG sudo "$username"        # Sudo privileges
    usermod -aG adm "$username"         # Administration group
    usermod -aG dialout "$username"     # Serial device access
    usermod -aG cdrom "$username"       # CD/DVD drive access
    usermod -aG dip "$username"         # VPN access
    usermod -aG video "$username"       # Video hardware access
    usermod -aG plugdev "$username"     # Pluggable devices
    
    # Add to docker group if it exists
    if getent group docker > /dev/null; then
        usermod -aG docker "$username"
        print_message "User added to docker group"
    fi
    
    print_success "User '$username' created successfully!"
    
    # Display user information
    print_message "=== USER INFORMATION ==="
    echo "Username: $username"
    echo "Home directory: /home/$username"
    echo "Shell: /bin/bash"
    echo "Groups: $(groups "$username" | cut -d: -f2 | sed 's/^ //')"
    echo
    
    # Create user information file
    create_user_info_file "$username" "$full_name" "$phone_number" "$email"
    
    # Test user configuration
    test_user_creation "$username"
    
    # Show final summary
    show_user_summary "$username"
    
    # Log user creation
    echo "$(date): Super user created - $username" >> /var/log/user_management.log
}

#===============================================================================
# USER INFORMATION AND TESTING FUNCTIONS
# Functions for creating info files and testing user configuration
#===============================================================================

# Function to create user information file
create_user_info_file() {
    local username=$1
    local full_name=$2
    local phone_number=$3
    local email=$4
    local info_file="/home/$username/user_account_info.txt"
    
    # Create information file
    cat > "$info_file" << EOF
Account Information Created:
============================
Username: $username
Full Name: ${full_name:-Not provided}
Phone: ${phone_number:-Not provided}
Email: ${email:-Not provided}
Creation Date: $(date)
Home Directory: /home/$username
Groups: $(groups "$username" | cut -d: -f2 | sed 's/^ //')

Instructions:
- To use super user privileges, use 'sudo' before commands
- Example: sudo apt update
- The first time you use sudo, you may be prompted for your password
- Keep your credentials secure!

System Information:
- Ubuntu Version: $(lsb_release -d | cut -f2)
- Kernel Version: $(uname -r)
- System Architecture: $(uname -m)
EOF
    
    # Set proper ownership and permissions
    chown "$username:$username" "$info_file"
    chmod 600 "$info_file"
    
    print_message "User account information file created at: $info_file"
}

# Function to test user creation and configuration
test_user_creation() {
    local username=$1
    print_message "=== TESTING CONFIGURATION ==="
    
    # Check if user exists
    if id "$username" &>/dev/null; then
        print_success "✓ User exists in system"
    else
        print_error "✗ User not found"
        return 1
    fi
    
    # Check if home directory exists
    if [[ -d "/home/$username" ]]; then
        print_success "✓ Home directory created"
    else
        print_error "✗ Home directory not found"
    fi
    
    # Check if user has sudo privileges
    if sudo -l -U "$username" &>/dev/null; then
        print_success "✓ User has sudo privileges"
    else
        print_error "✗ User does not have sudo privileges"
    fi
    
    # Test authentication (simulation)
    print_message "Testing authentication..."
    if su - "$username" -c "whoami" 2>/dev/null | grep -q "$username"; then
        print_success "✓ Authentication working"
    else
        print_warning "? Authentication test could not be completed"
    fi
    
    # Check shell configuration
    if getent passwd "$username" | grep -q "/bin/bash"; then
        print_success "✓ Bash shell configured"
    else
        print_warning "? Different shell configured"
    fi
}

#===============================================================================
# USER MANAGEMENT FUNCTIONS
# Functions for listing, viewing, and managing existing users
#===============================================================================

# Function to list all users
list_users() {
    print_header "=== SYSTEM USERS ==="
    echo
    
    print_message "Regular Users (UID >= 1000):"
    awk -F: '$3 >= 1000 && $3 != 65534 {
        printf "  %-15s | UID: %-5s | Home: %-20s | Shell: %s\n", $1, $3, $6, $7
    }' /etc/passwd
    
    echo
    print_message "System Users (UID < 1000):"
    awk -F: '$3 < 1000 {
        printf "  %-15s | UID: %-5s | Home: %-20s | Shell: %s\n", $1, $3, $6, $7
    }' /etc/passwd | head -10
    echo "  ... (showing first 10 system users)"
}

# Function to show detailed user information
show_user_details() {
    print_header "=== USER DETAILS ==="
    echo
    
    # List available users
    print_message "Available users:"
    awk -F: '$3 >= 1000 && $3 != 65534 {print "  - " $1}' /etc/passwd
    echo
    
    read -p "Enter username to view details: " username
    
    # Check if user exists
    if ! id "$username" &>/dev/null; then
        print_error "User '$username' does not exist!"
        return 1
    fi
    
    # Get user information
    user_info=$(getent passwd "$username")
    IFS=':' read -r uname upass uid gid gecos home shell <<< "$user_info"
    
    print_highlight "User Information for: $username"
    echo "=================================="
    echo "Username: $uname"
    echo "User ID (UID): $uid"
    echo "Group ID (GID): $gid"
    echo "Full Name: ${gecos:-Not set}"
    echo "Home Directory: $home"
    echo "Shell: $shell"
    
    # Show groups
    echo "Groups: $(groups "$username" | cut -d: -f2 | sed 's/^ //')"
    
    # Show last login
    if last "$username" | head -1 | grep -v "wtmp begins" >/dev/null 2>&1; then
        echo "Last Login: $(last "$username" | head -1 | awk '{print $3, $4, $5, $6, $7}')"
    else
        echo "Last Login: Never logged in"
    fi
    
    # Show disk usage of home directory
    if [[ -d "$home" ]]; then
        disk_usage=$(du -sh "$home" 2>/dev/null | cut -f1)
        echo "Home Directory Size: ${disk_usage:-Unknown}"
    fi
    
    # Check if user is currently logged in
    if who | grep -q "$username"; then
        echo "Status: Currently logged in"
    else
        echo "Status: Not logged in"
    fi
    
    echo
}

# Function to remove a user
remove_user() {
    print_header "=== REMOVE USER ==="
    echo
    
    # List available users
    print_message "Available users:"
    awk -F: '$3 >= 1000 && $3 != 65534 {print "  - " $1}' /etc/passwd
    echo
    
    read -p "Enter username to remove: " username
    
    # Check if user exists
    if ! id "$username" &>/dev/null; then
        print_error "User '$username' does not exist!"
        return 1
    fi
    
    # Safety check - don't remove critical users
    if [[ "$username" == "root" || "$username" == "ubuntu" ]]; then
        print_error "Cannot remove critical system user '$username'!"
        return 1
    fi
    
    # Show user information before removal
    print_warning "User information:"
    getent passwd "$username" | awk -F: '{print "  Username: " $1 "\n  Home: " $6 "\n  Shell: " $7}'
    echo
    
    # Confirmation prompts
    print_warning "This action will permanently remove the user and all their data!"
    read -p "Are you sure you want to remove user '$username'? (yes/no): " confirm1
    
    if [[ "$confirm1" != "yes" ]]; then
        print_message "User removal cancelled."
        return 0
    fi
    
    read -p "Remove home directory and mail spool? (y/n): " remove_home
    
    print_warning "FINAL WARNING: This cannot be undone!"
    read -p "Type 'DELETE' to confirm: " final_confirm
    
    if [[ "$final_confirm" != "DELETE" ]]; then
        print_message "User removal cancelled."
        return 0
    fi
    
    # Remove user
    print_message "Removing user '$username'..."
    
    if [[ "$remove_home" =~ ^[Yy]$ ]]; then
        userdel -r "$username"
    else
        userdel "$username"
    fi
    
    if [[ $? -eq 0 ]]; then
        print_success "User '$username' removed successfully!"
        
        # Log user removal
        echo "$(date): User removed - $username" >> /var/log/user_management.log
    else
        print_error "Failed to remove user '$username'!"
        return 1
    fi
}

#===============================================================================
# SUMMARY AND INFORMATION FUNCTIONS
# Functions for displaying summaries and system information
#===============================================================================

# Function to show user creation summary
show_user_summary() {
    local username=$1
    echo
    print_success "=== SUPER USER CREATED SUCCESSFULLY! ==="
    echo
    print_message "Creation Summary:"
    print_success "✓ Username: $username"
    print_success "✓ Home Directory: /home/$username"
    print_success "✓ Shell: /bin/bash"
    print_success "✓ Groups: $(groups "$username" | cut -d: -f2 | sed 's/^ //')"
    echo
    print_warning "IMPORTANT NOTES:"
    print_message "1. Save credentials in a secure location"
    print_message "2. User can use 'sudo' for administrative commands"
    print_message "3. Recommend changing password periodically"
    print_message "4. Information file saved at: /home/$username/user_account_info.txt"
    echo
}

# Function to show system information
show_system_info() {
    print_header "=== SYSTEM INFORMATION ==="
    echo
    
    print_highlight "Operating System:"
    lsb_release -a 2>/dev/null | grep -E "(Description|Release|Codename)"
    
    echo
    print_highlight "System Details:"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p)"
    
    echo
    print_highlight "User Statistics:"
    total_users=$(awk -F: '$3 >= 1000 && $3 != 65534' /etc/passwd | wc -l)
    logged_in_users=$(who | wc -l)
    echo "Total Users: $total_users"
    echo "Currently Logged In: $logged_in_users"
    
    echo
    print_highlight "Disk Usage:"
    df -h / | tail -1 | awk '{print "Root Partition: " $3 " used of " $2 " (" $5 " full)"}'
    
    echo
    print_highlight "Memory Usage:"
    free -h | awk 'NR==2{print "RAM: " $3 " used of " $2}'
    
    echo
}

#===============================================================================
# MENU FUNCTIONS
# Interactive menu system for user management
#===============================================================================

# Function for user management submenu
user_management_menu() {
    while true; do
        echo
        print_header "=== USER MANAGEMENT MENU ==="
        echo "1. Create Super User"
        echo "2. List All Users"
        echo "3. Show User Details"
        echo "4. Change User Password"
        echo "5. Remove User"
        echo "6. Back to Main Menu"
        echo "7. Exit"
        echo
        read -p "Choose an option: " choice
        
        case $choice in
            1) create_super_user ;;
            2) list_users ;;
            3) show_user_details ;;
            4) change_user_password ;;
            5) remove_user ;;
            6) return 0 ;;
            7) exit 0 ;;
            *) print_error "Invalid option" ;;
        esac
        
        # Pause before showing menu again
        echo
        read -p "Press Enter to continue..."
    done
}

# Main menu function
main_menu() {
    while true; do
        echo
        print_header "=== UBUNTU SUPER USER MANAGER ==="
        print_highlight "Welcome! What would you like to do?"
        echo
        echo "1. User Management"
        echo "2. System Information"
        echo "3. Exit"
        echo
        read -p "Choose an option: " choice
        
        case $choice in
            1) user_management_menu ;;
            2) show_system_info ;;
            3) 
                print_message "Goodbye!"
                exit 0
                ;;
            *) print_error "Invalid option" ;;
        esac
        
        # Pause before showing menu again
        echo
        read -p "Press Enter to continue..."
    done
}

#===============================================================================
# INITIALIZATION FUNCTIONS
# Script initialization and setup
#===============================================================================

# Function to initialize log file
initialize_logging() {
    local log_file="/var/log/user_management.log"
    
    # Create log file if it doesn't exist
    if [[ ! -f "$log_file" ]]; then
        touch "$log_file"
        chmod 644 "$log_file"
        echo "$(date): User management log initialized" >> "$log_file"
    fi
}

# Function to check system requirements
check_system_requirements() {
    # Check if required commands are available
    local required_commands=("useradd" "usermod" "userdel" "chpasswd" "groups" "id")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "Required command '$cmd' not found!"
            print_message "Please install the necessary packages."
            exit 1
        fi
    done
    
    # Check if /etc/passwd is readable
    if [[ ! -r /etc/passwd ]]; then
        print_error "Cannot read /etc/passwd file!"
        exit 1
    fi
}

#===============================================================================
# MAIN FUNCTION
# Script entry point and initialization
#===============================================================================

# Main function - script entry point
main() {
    # Clear screen for better presentation
    clear
    
    print_message "Initializing Ubuntu Super User Manager..."
    echo
    
    # Perform initial checks
    check_root
    check_system_requirements
    initialize_logging
    
    # Show welcome message
    print_success "System checks completed successfully!"
    echo
    
    # Start main menu
    main_menu
}

#===============================================================================
# SCRIPT EXECUTION
# Execute the main function with all provided arguments
#===============================================================================

# Execute the main function with all command line arguments
main "$@"