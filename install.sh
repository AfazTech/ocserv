#!/bin/bash

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

# Check if the OS is CentOS 7
if ! grep -q "CentOS Linux release 7" /etc/centos-release; then
  echo "This script is for CentOS 7."
  exit 1
fi

# Check if SELinux is enabled and prompt the user to disable it
if [ "$(getenforce)" != "Disabled" ]; then
  echo "SELinux is enabled. Please run the following commands to disable it and then rerun this script:"
  echo "setenforce 0"
  echo "sed -i 's/enforcing/disabled/g' /etc/selinux/config"
  exit 1
fi

# Add nameserver 8.8.8.8 to the beginning of /etc/resolv.conf if it doesn't already exist
if ! grep -q "nameserver 8.8.8.8" /etc/resolv.conf; then
  sed -i "1inameserver 8.8.8.8" /etc/resolv.conf
fi

# Fix CentOS 7 repository
yum remove epel-release -y
bash <(curl -s https://raw.githubusercontent.com/imafaz/awesome-scripts/main/fix-centos7-repository/main.sh)

# Update system packages
echo "Updating system packages..."
yum update -y

# Install necessary packages
yum install epel-release -y
yum install ocserv firewalld radcli certbot -y

# Check if packages were installed successfully
for package in epel-release ocserv firewalld radcli certbot; do
  if ! rpm -q $package &>/dev/null; then
    echo "The package $package was not installed correctly."
    exit 1
  fi
done

# Enable and start firewalld and ocserv services
systemctl enable firewalld
systemctl start firewalld
systemctl enable ocserv

# Prompt the user for input
read -p "Please enter the ocserv port (example: 443): " ocserv_port
read -p "Please enter your domain (example: ocserv.domain.com): " domain
read -p "Please enter the ibsng IP (example: 45.89.36.36): " ibsng_ip
read -p "Please enter the ibsng secret (example: 123): " ibsng_secret

# Configure firewall rules
firewall-cmd --permanent --add-port=$ocserv_port/tcp
firewall-cmd --permanent --add-port=$ocserv_port/udp
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --zone=public --add-masquerade --permanent
systemctl reload firewalld

# Check if SSL certificates already exist
if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$domain/privkey.pem" ]; then
  echo "SSL certificates already exist. Moving them to the appropriate locations."
  cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/pki/ocserv/public/server.crt
  cp /etc/letsencrypt/live/$domain/privkey.pem /etc/pki/ocserv/private/server.key
else
  # Obtain SSL certificate using certbot
  certbot certonly --manual --preferred-challenges dns --agree-tos --register-unsafely-without-email -d $domain

  # Check the exit status of the certbot command
  if [ $? -ne 0 ]; then
      echo "The certbot command failed. Please resolve the issues and run the script again."
      exit 1
  fi

  # Move the obtained certificates to the appropriate locations
  cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/pki/ocserv/public/server.crt
  cp /etc/letsencrypt/live/$domain/privkey.pem /etc/pki/ocserv/private/server.key
fi

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -p

# Stop ocserv service and remove existing configuration files
systemctl stop ocserv

# Download and configure new ocserv and radiusclient configuration files
curl -4 https://raw.githubusercontent.com/imafaz/ocserv/main/ocserv.conf -o /etc/ocserv/ocserv.conf
sed -i "s/ocserv_port/$ocserv_port/g" /etc/ocserv/ocserv.conf
curl -4 https://raw.githubusercontent.com/imafaz/ocserv/main/radiusclient.conf -o /etc/radcli/radiusclient.conf
sed -i "s/ibsng_ip/$ibsng_ip/g" /etc/radcli/radiusclient.conf
curl -4 https://raw.githubusercontent.com/imafaz/ocserv/main/servers -o /etc/radcli/servers
sed -i "s/ibsng_ip/$ibsng_ip/g" /etc/radcli/servers
sed -i "s/ibsng_secret/$ibsng_secret/g" /etc/radcli/servers

# Start ocserv service
systemctl start ocserv

# Display success message
echo "Installation successful. You can connect to this server with the address:"
echo "$domain:$ocserv_port"