#!/bin/bash
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions to print colored messages
print_message() {
echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if script is being run as root
check_root() {
if [[ $EUID -ne 0 ]]; then
print_error "This script needs to be run as root!"
exit 1
fi
}

# Function to update system packages
update_packages() {
print_message "Updating package list..."
apt-get update
if [ $? -eq 0 ]; then
print_success "Package list updated successfully!"
else
print_error "Failed to update package list"
exit 1
fi

print_message "Updating system packages..."
apt-get upgrade -y
if [ $? -eq 0 ]; then
print_success "Packages updated successfully!"
else
print_error "Failed to update packages"
exit 1
fi
}

# Function to install Docker
install_docker() {
print_message "Checking if Docker is already installed..."
if command -v docker &> /dev/null; then
print_warning "Docker is already installed. Skipping installation..."
return 0
fi

print_message "Installing necessary dependencies..."
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

print_message "Adding Docker repository..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Detect distribution
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

print_message "Updating package list after adding Docker repository..."
apt-get update

print_message "Installing Docker..."
apt-get install -y docker-ce docker-ce-cli containerd.io

if [ $? -eq 0 ]; then
print_success "Docker installed successfully!"
print_message "Starting and enabling Docker service..."
systemctl start docker
systemctl enable docker

# Add current user to docker group (if not root)
if [[ $EUID -ne 0 ]]; then
print_message "Adding user $SUDO_USER to docker group..."
usermod -aG docker $SUDO_USER
print_warning "Please restart your session or run 'newgrp docker' for changes to take effect"
fi
else
print_error "Docker installation failed"
exit 1
fi
}

# Function to configure Git
configure_git() {
print_message "Configuring Git..."

# Check if Git is installed, if not, install it
if ! command -v git &> /dev/null; then
print_message "Git not found. Installing..."
apt-get install -y git
fi

# Request user data
echo
print_message "Git Configuration"
read -p "Enter your Git username: " git_username
read -p "Enter your Git email: " git_email

# Configure user and email globally
git config --global user.name "$git_username"
git config --global user.email "$git_email"

# Additional useful configurations
git config --global init.defaultBranch main
git config --global pull.rebase false

print_success "Git configured successfully!"
echo
print_message "Git settings:"
git config --global --list
echo
}

# Function to install Nginx
install_nginx() {
print_message "Checking if Nginx is already installed..."
if command -v nginx &> /dev/null; then
print_warning "Nginx is already installed. Skipping installation..."
return 0
fi

print_message "Installing Nginx..."
apt-get install -y nginx

if [ $? -eq 0 ]; then
print_success "Nginx installed successfully!"
print_message "Starting and enabling Nginx service..."
systemctl start nginx
systemctl enable nginx

# Check service status
if systemctl is-active --quiet nginx; then
print_success "Nginx service is running!"
else
print_error "Nginx service is not running"
fi
else
print_error "Nginx installation failed"
exit 1
fi
}

# Adjusted function for installation with port prompt
quick_install_portainer() {
local PORT

# Request port via prompt if not passed as parameter
if [ -z "$1" ]; then
read -p "Enter port for Portainer [Default-9000]: " PORT
PORT=${PORT:-9000}
else
PORT=$1
fi

# Validate if port is a valid number
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
echo "Error: Invalid port! Must be a number between 1 and 65535."
return 1
fi

# Check if port is already in use
if netstat -tuln | grep ":$PORT " > /dev/null; then
echo "Error: Port $PORT is already in use!"
read -p "Do you want to try another port? (y/N): " try_again
if [[ $try_again =~ ^[Yy]$ ]]; then
quick_install_portainer  # Calls recursively without parameter
return
else
return 1
fi
fi

echo "Installing Portainer CE on port $PORT..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
echo "Error: Docker not found. Install Docker first."
return 1
fi

# Check if Docker service is running
if ! systemctl is-active --quiet docker; then
echo "Starting Docker service..."
sudo systemctl start docker
fi

# Create data directory
sudo mkdir -p /opt/portainer

# Stop existing container if any
if docker ps -a | grep -q portainer; then
echo "Stopping existing Portainer container..."
sudo docker stop portainer > /dev/null 2>&1
sudo docker rm portainer > /dev/null 2>&1
fi

# Run container
echo "Starting Portainer CE container..."
sudo docker run -d \
--name portainer \
--restart always \
-p $PORT:9000 \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /opt/portainer:/data \
portainer/portainer-ce:latest

if [ $? -eq 0 ]; then
local IP_ADDRESS
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "✅ Portainer CE installed successfully!"
echo "🌐 Access: http://$IP_ADDRESS:$PORT"
echo "💻 Or locally: http://localhost:$PORT"

# Wait for initialization
echo "⏳ Waiting for initialization..."
sleep 5

# Check status
if docker ps | grep -q portainer; then
echo "✅ Container is running correctly"
else
echo "⚠️ Container may have issues. Check with: docker logs portainer"
fi
else
echo "❌ Error installing Portainer CE"
return 1
fi
}

# More interactive alternative version
interactive_install_portainer() {
echo "=== INTERACTIVE PORTAINER INSTALLATION ==="

# Request port with validation
while true; do
read -p "Enter port for Portainer [9000]: " PORT
PORT=${PORT:-9000}

# Validate port
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
echo "❌ Invalid port! Must be a number between 1 and 65535."
continue
fi

# Check if port is available
if netstat -tuln | grep ":$PORT " > /dev/null; then
echo "❌ Port $PORT is already in use!"
read -p "Do you want to try another port? (y/N): " try_again
if [[ ! $try_again =~ ^[Yy]$ ]]; then
return 1
fi
else
break
fi
done

# Call installation function with chosen port
quick_install_portainer "$PORT"
}

# Function to show installation summary
show_summary() {
echo
print_success "=== INSTALLATION COMPLETED ==="
echo
print_message "Installation summary:"

# Check Docker
if command -v docker &> /dev/null; then
docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
print_success "✓ Docker: $docker_version"
else
print_error "✗ Docker: Not installed"
fi

# Check Git
if command -v git &> /dev/null; then
git_version=$(git --version | cut -d' ' -f3)
print_success "✓ Git: $git_version"
print_message "  User: $(git config --global user.name)"
print_message "  Email: $(git config --global user.email)"
else
print_error "✗ Git: Not installed"
fi

# Check Nginx
if command -v nginx &> /dev/null; then
nginx_version=$(nginx -v 2>&1 | cut -d'/' -f2)
print_success "✓ Nginx: $nginx_version"

# Check service status
if systemctl is-active --quiet nginx; then
print_success "  Status: Running"
print_message "  URL: http://$(curl -s ifconfig.me) or http://localhost"
else
print_warning "  Status: Stopped"
fi
else
print_error "✗ Nginx: Not installed"
fi
echo
}

all_inclusive() {
# Update packages
update_packages
echo

# Install Docker
install_docker
echo

# Configure Git
configure_git
echo

# Install Nginx
install_nginx
echo

# Show summary
show_summary
}

# Function to configure Nginx service with DNS
configure_nginx_service() {
local DOMAIN
local PORT
local SERVICE_NAME
local CONFIG_DIR="/etc/nginx/sites-available"
local ENABLED_DIR="/etc/nginx/sites-enabled"
local SSL_ENABLED=false

echo "=== NGINX SERVICE CONFIGURATOR ==="

# Check if Nginx is installed
if ! command -v nginx &> /dev/null; then
echo "❌ Nginx not found. Install first: sudo apt install nginx"
return 1
fi

# Request service information
read -p "🔤 Enter service name (ex: myservice): " SERVICE_NAME
SERVICE_NAME=$(echo "$SERVICE_NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

read -p "🌐 Enter domain (ex: app.mydomain.com): " DOMAIN
DOMAIN=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]')

read -p "🔢 Enter service port (ex: 3000, 8080): " PORT

# Validate port
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
echo "❌ Invalid port!"
return 1
fi

# Ask about SSL
read -p "🔒 Enable HTTPS/SSL? (y/N): " enable_ssl
if [[ $enable_ssl =~ ^[Yy]$ ]]; then
SSL_ENABLED=true
fi

# Create Nginx configuration
create_nginx_config "$SERVICE_NAME" "$DOMAIN" "$PORT" "$SSL_ENABLED"

# Configure local DNS (optional)
setup_local_dns "$DOMAIN"

# Test and reload Nginx
test_and_reload_nginx
}

# Function to create Nginx configuration
create_nginx_config() {
local SERVICE_NAME=$1
local DOMAIN=$2
local PORT=$3
local SSL_ENABLED=$4
local CONFIG_FILE="/etc/nginx/sites-available/$SERVICE_NAME"
local CERT_DIR="/etc/nginx/ssl/$SERVICE_NAME"

echo "📁 Creating Nginx configuration for $DOMAIN..."

# Create SSL directory if necessary
if [ "$SSL_ENABLED" = true ]; then
sudo mkdir -p "$CERT_DIR"
echo "📝 Creating self-signed certificate (for development)..."

# Create self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
-keyout "$CERT_DIR/$SERVICE_NAME.key" \
-out "$CERT_DIR/$SERVICE_NAME.crt" \
-subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
fi

# Create configuration file
sudo tee "$CONFIG_FILE" > /dev/null << EOF
# Configuration for $SERVICE_NAME
# Domain: $DOMAIN
# Service port: $PORT

server {
    listen 80;
    server_name $DOMAIN;
    $(if [ "$SSL_ENABLED" = true ]; then echo "return 301 https://\$server_name\$request_uri;"; fi)
}

$(if [ "$SSL_ENABLED" = true ]; then
echo "
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate $CERT_DIR/$SERVICE_NAME.crt;
    ssl_certificate_key $CERT_DIR/$SERVICE_NAME.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_connect_timeout       60;
        proxy_send_timeout          60;
        proxy_read_timeout          60;
    }

    # Security configurations
    add_header X-Frame-Options \"SAMEORIGIN\" always;
    add_header X-XSS-Protection \"1; mode=block\" always;
    add_header X-Content-Type-Options \"nosniff\" always;
    add_header Referrer-Policy \"no-referrer-when-downgrade\" always;

    # Cache configurations
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control \"public, immutable\";
    }
}"
else
echo "
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Logs
    access_log /var/log/nginx/${SERVICE_NAME}_access.log;
    error_log /var/log/nginx/${SERVICE_NAME}_error.log;
}"
fi)
EOF

# Enable site
sudo ln -sf "$CONFIG_FILE" "/etc/nginx/sites-enabled/$SERVICE_NAME"
echo "✅ Configuration created: $CONFIG_FILE"
}

# Function to configure local DNS
setup_local_dns() {
local DOMAIN=$1
local HOSTS_FILE="/etc/hosts"

read -p "🌍 Configure local DNS in /etc/hosts? (y/N): " setup_dns
if [[ $setup_dns =~ ^[Yy]$ ]]; then
# Get local IP
local IP_LOCAL
IP_LOCAL=$(hostname -I | awk '{print $1}')

# Check if entry already exists
if ! grep -q "$DOMAIN" "$HOSTS_FILE"; then
echo "📝 Adding $DOMAIN to /etc/hosts..."
echo "# Automatically configured - $SERVICE_NAME" | sudo tee -a "$HOSTS_FILE" > /dev/null
echo "$IP_LOCAL $DOMAIN" | sudo tee -a "$HOSTS_FILE" > /dev/null
echo "✅ Local DNS configured: $DOMAIN -> $IP_LOCAL"
else
echo "⚠️  Domain $DOMAIN already exists in /etc/hosts"
fi
fi
}

# Function to test and reload Nginx
test_and_reload_nginx() {
echo "🔍 Testing Nginx configuration..."
if sudo nginx -t; then
echo "✅ Nginx configuration is valid"
echo "🔄 Reloading Nginx..."
sudo systemctl reload nginx
echo "✅ Nginx reloaded successfully!"

# Show summary
show_nginx_summary
else
echo "❌ Error in Nginx configuration. Check the files."
return 1
fi
}

# Function to list configured services
list_nginx_services() {
echo "=== CONFIGURED NGINX SERVICES ==="
if [ -d "/etc/nginx/sites-enabled" ]; then
for config in /etc/nginx/sites-enabled/*; do
if [ -f "$config" ]; then
local service_name=$(basename "$config")
local domain=$(grep -m1 "server_name" "$config" | awk '{print $2}' | tr -d ';')
local port=$(grep -m1 "proxy_pass" "$config" | grep -oE '[0-9]+')
echo "🔧 $service_name | Domain: $domain | Port: $port"
fi
done
else
echo "❌ No services configured"
fi
}

# Function to remove service
remove_nginx_service() {
echo "=== REMOVE NGINX SERVICE ==="
list_nginx_services
read -p "🔤 Enter service name to remove: " SERVICE_NAME

local CONFIG_FILE="/etc/nginx/sites-available/$SERVICE_NAME"
local ENABLED_FILE="/etc/nginx/sites-enabled/$SERVICE_NAME"

if [ -f "$ENABLED_FILE" ]; then
sudo rm -f "$ENABLED_FILE"
echo "✅ Service disabled"
fi

if [ -f "$CONFIG_FILE" ]; then
read -p "🗑️  Remove configuration file too? (y/N): " remove_config
if [[ $remove_config =~ ^[Yy]$ ]]; then
sudo rm -f "$CONFIG_FILE"
echo "✅ Configuration file removed"
fi
fi

sudo systemctl reload nginx
echo "✅ Nginx reloaded"
}

# Function to show configuration summary
show_nginx_summary() {
local SERVICE_NAME=$1
local DOMAIN=$2
local PORT=$3
local SSL_ENABLED=$4

echo ""
echo "🎉 CONFIGURATION COMPLETED!"
echo "=========================="
echo "📋 Service: $SERVICE_NAME"
echo "🌐 Domain: $DOMAIN"
echo "🔢 Service port: $PORT"
echo "🔒 SSL: $([ "$SSL_ENABLED" = true ] && echo "Enabled" || echo "Disabled")"
echo ""
echo "🔗 Access URLs:"
if [ "$SSL_ENABLED" = true ]; then
echo "   HTTPS: https://$DOMAIN"
echo "   HTTP: http://$DOMAIN (redirects to HTTPS)"
else
echo "   HTTP: http://$DOMAIN"
fi
echo ""
echo "📁 Configuration files:"
echo "   Config: /etc/nginx/sites-available/$SERVICE_NAME"
echo "   Enabled: /etc/nginx/sites-enabled/$SERVICE_NAME"
if [ "$SSL_ENABLED" = true ]; then
echo "   Certificate: /etc/nginx/ssl/$SERVICE_NAME/"
fi
echo ""
echo "📊 Logs:"
echo "   Access: /var/log/nginx/${SERVICE_NAME}_access.log"
echo "   Error: /var/log/nginx/${SERVICE_NAME}_error.log"
echo ""
}

# Interactive nginx services menu
nginx_service_menu() {
while true; do
echo ""
echo "=== NGINX SERVICES MENU ==="
echo "1. Configure new service"
echo "2. List services"
echo "3. Remove service"
echo "4. Back to main menu"
echo "5. Exit"
read -p "Choose: " choice

case $choice in
1) configure_nginx_service ;;
2) list_nginx_services ;;
3) remove_nginx_service ;;
4) setup_menu ;;
5) break ;;
*) echo "❌ Invalid option" ;;
esac
done
}

setup_menu() {
while true; do
echo
echo "=== Hey buddy, what's up? What do you need? ==="
echo "1. Configure Domain|DNS"
echo "2. Complete setup:"
echo "   ├── System update"
echo "   ├── Docker installation"
echo "   ├── Git configuration"
echo "   └── Nginx installation"
echo "3. Exit"
read -p "Choose an option: " choice

case $choice in
1) nginx_service_menu;;
2) all_inclusive;;
3) break ;;
*) print_error "Invalid option" ;;
esac
done
}

# Main function
main() {
clear
print_message "Starting script..."
echo

# Check if running as root
check_root

# setup_menu
setup_menu
}

# Execute main function
main