# Linux Cloud Automation Scripts

A comprehensive collection of Bash scripts designed to automate the setup and configuration of Linux services and environments in cloud infrastructure.

## 📋 Overview

This repository provides production-ready automation scripts for Linux cloud servers, focusing on rapid deployment, security best practices, and standardized configurations. Whether you're setting up a single server or managing multiple cloud instances, these scripts will help you achieve consistent and reliable deployments.

## 🚀 Features

### Server Setup & Configuration
- **Complete Ubuntu Server Setup**: Automated system updates, Docker installation, Git configuration, and Nginx deployment
- **Service Management**: Configure and manage web services with custom domains and SSL certificates
- **User Management**: Create and manage super users with appropriate permissions and security settings

### Security & Best Practices
- **SSL/TLS Configuration**: Automated certificate generation and HTTPS setup
- **User Permission Management**: Secure user creation with validated credentials
- **System Hardening**: Security-focused configurations for production environments

### Cloud-Ready Features
- **DNS Management**: Local DNS configuration and domain setup
- **Reverse Proxy Configuration**: Nginx-based service routing and load balancing
- **Container Support**: Docker integration and container management
- **Service Discovery**: Automated service detection and configuration

## 🛠️ Scripts Overview

**Use Cases**:
- Team member onboarding
- Service account creation
- Administrative access management
- User privilege auditing

## 🚦 Quick Start

### Prerequisites
- Ubuntu 18.04+ or compatible Linux distribution
- Root or sudo access
- Internet connection for package downloads

### Installation

1. **Make scripts executable**:
```bash
chmod +x *.sh
```

2. **Run the desired script**:
```bash
# For complete server setup
sudo ./setup_environment.sh

# For user management
sudo ./create_super_user.sh
```

## 📖 Usage Examples

### Complete Server Setup
```bash
# Run interactive server setup
sudo ./ubuntu-server-setup.sh

# Follow the menu options:
# 1. Configure Domain/DNS
# 2. Complete Installation (Docker, Git, Nginx)
# 3. Exit
```

### User Management
```bash
# Run user management system
sudo ./super-user-creator.sh

# Available options:
# 1. Create super user
# 2. List system users
# 3. Show user details
# 4. Change user password
# 5. Remove user
```

### Service Configuration
The scripts provide interactive configuration for:
- **Custom domains** with automatic Nginx virtual host setup
- **SSL certificates** (self-signed for development, Let's Encrypt ready)
- **Reverse proxy** configuration for applications
- **Docker containers** with Portainer management interface

### Custom Configurations
- **Nginx Templates**: Modify service templates in the script for custom configurations
- **User Groups**: Customize default group assignments for new users
- **Security Policies**: Adjust password complexity requirements

## 🔒 Security Features

### User Security
- **Password Validation**: Enforced complexity requirements
- **Group Management**: Automatic assignment to appropriate groups
- **Audit Logging**: User creation and modification tracking
- **Access Control**: Sudo privilege management

### Service Security
- **SSL/TLS**: Automatic HTTPS configuration
- **Firewall Ready**: Scripts compatible with UFW and iptables
- **Secure Defaults**: Production-ready security configurations
- **Certificate Management**: Automated certificate generation

## 🌐 Cloud Platform Compatibility

### Supported Platforms
- ✅ **AWS EC2** (Amazon Linux, Ubuntu)
- ✅ **Google Cloud Platform** (Compute Engine)
- ✅ **Microsoft Azure** (Virtual Machines)
- ✅ **DigitalOcean** (Droplets)
- ✅ **Linode** (Compute Instances)
- ✅ **Vultr** (Cloud Compute)

### Cloud-Specific Features
- **Instance Metadata**: Automatic detection of cloud environment
- **Network Configuration**: Cloud-native networking support
- **Storage Integration**: EBS, Persistent Disk compatibility
- **Load Balancer Ready**: ALB, GCP LB, Azure LB integration

## 🔄 Automation & CI/CD

### Integration Examples

**Terraform Integration**:
```hcl
resource "aws_instance" "web_server" {
  # ... instance configuration ...
  
  user_data = <<-EOF
    #!/bin/bash
    wget https://raw.githubusercontent.com/your-repo/ubuntu-server-setup.sh
    chmod +x ubuntu-server-setup.sh
    AUTO_MODE=true ./ubuntu-server-setup.sh
  EOF
}
```

**Docker Integration**:
```dockerfile
FROM ubuntu:20.04
COPY ubuntu-server-setup.sh /setup.sh
RUN chmod +x /setup.sh && /setup.sh
```

## 📊 Monitoring & Logging

### Built-in Logging
- User creation activities logged to `/var/log/user-management.log`
- Service configuration logs in `/var/log/nginx/`
- System service logs via `systemctl status`

### Monitoring Integration
Scripts are compatible with:
- **Prometheus** + Grafana monitoring
- **ELK Stack** (Elasticsearch, Logstash, Kibana)
- **Cloud-native monitoring** (CloudWatch, Stackdriver)

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Test thoroughly** on multiple Ubuntu versions
4. **Add documentation** for new features
5. **Submit a pull request**

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support & Troubleshooting

### Common Issues

**Permission Denied**:
```bash
# Ensure scripts have execute permissions
chmod +x *.sh
```

## 🔗 Related Resources

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Configuration Guide](https://nginx.org/en/docs/)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
