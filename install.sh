#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

if ! grep -qi 'debian\|ubuntu\|centos\|rhel\|rocky\|fedora\|alma' /etc/os-release; then
  echo "Unsupported OS. This script supports Debian-based and RHEL-based systems."
  exit 1
fi

if command -v getenforce &>/dev/null; then
  if [ "$(getenforce)" != "Disabled" ]; then
    echo "SELinux is enabled. Please run the following commands to disable it and then rerun this script:"
    echo ""
    echo "sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config && reboot"
    exit 1
  fi
fi

if ! grep -q "nameserver 8.8.8.8" /etc/resolv.conf; then
  sed -i "1inameserver 8.8.8.8" /etc/resolv.conf
fi

. /etc/os-release

read -p "Please enter the ocserv port (example: 443): " ocserv_port
read -p "Please enter your domain (example: vpn.example.com): " domain

echo "Choose authentication method:"
echo "1) Local (ocpasswd)"
echo "2) Linux PAM"
echo "3) Radius with IBSng"
read -p "Enter choice [1-3]: " authChoice
if [[ "$authChoice" != "1" && "$authChoice" != "2" && "$authChoice" != "3" ]]; then
  echo "Invalid choice. Please enter 1, 2, or 3."
  exit 1
fi


if [[ "$ID_LIKE" == *debian* || "$ID" == *debian* || "$ID" == *ubuntu* ]]; then
  apt update
  if [[ "$authChoice" == "3" ]]; then
    apt install -y ocserv iptables iptables-persistent libradcli-dev certbot curl
  else
    apt install -y ocserv iptables iptables-persistent certbot curl
  fi
  systemctl stop ufw 2>/dev/null
  systemctl disable ufw 2>/dev/null
  systemctl enable iptables 2>/dev/null
  systemctl start iptables 2>/dev/null
  radcliConfDir="/etc/radiusclient"
elif [[ "$ID" == *centos* || "$ID" == *rhel* || "$ID" == *rocky* || "$ID" == *alma* || "$ID" == *fedora* ]]; then
yum install -y epel-release
  if [[ "$authChoice" == "3" ]]; then
    yum install -y ocserv iptables iptables-services radcli certbot curl
  else
    yum install -y ocserv iptables iptables-services certbot curl
  fi
  systemctl stop firewalld 2>/dev/null
  systemctl disable firewalld 2>/dev/null
  systemctl enable iptables 2>/dev/null
  systemctl start iptables 2>/dev/null
  radcliConfDir="/etc/radcli"
else
  echo "OS not recognized. Exiting."
  exit 1
fi

if [[ "$authChoice" == "3" ]]; then
  read -p "Please enter the IBSng IP (example: 45.89.36.36): " ibsng_ip
  read -p "Please enter the IBSng secret (example: 123): " ibsng_secret
fi
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport $ocserv_port -j ACCEPT
iptables -A INPUT -p udp --dport $ocserv_port -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

iface=$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}')
iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE


if command -v netfilter-persistent &>/dev/null; then
  netfilter-persistent save
elif grep -qi 'centos\|rhel\|rocky\|alma' /etc/os-release; then
  iptables-save > /etc/sysconfig/iptables
else
  iptables-save > /etc/iptables/rules.v4
fi



if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$domain/privkey.pem" ]; then
  echo "SSL certificates already exist. Moving them."
else
  certbot certonly --manual --preferred-challenges dns --agree-tos --register-unsafely-without-email -d $domain || exit 1
fi

mkdir -p /etc/pki/ocserv/public /etc/pki/ocserv/private
cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/pki/ocserv/public/server.crt
cp /etc/letsencrypt/live/$domain/privkey.pem /etc/pki/ocserv/private/server.key

sysctl -w net.ipv4.ip_forward=1
sysctl -p

systemctl stop ocserv

curl -4 https://raw.githubusercontent.com/imafaz/ocserv/main/confs/ocserv.conf -o /etc/ocserv/ocserv.conf
sed -i "s/ocserv_port/$ocserv_port/g" /etc/ocserv/ocserv.conf

sed -i 's/^auth =.*//g' /etc/ocserv/ocserv.conf
sed -i 's/^acct =.*//g' /etc/ocserv/ocserv.conf

case "$authChoice" in
  1)
    sed -i '1i auth = "plain[passwd=/etc/ocserv/ocpasswd]"' /etc/ocserv/ocserv.conf
    read -p "Enter VPN username: " vpnUser
    ocpasswd -c /etc/ocserv/ocpasswd $vpnUser
    ;;
  2)
    sed -i '1i auth = "pam"' /etc/ocserv/ocserv.conf
    ;;
  3)
    sed -i "1i auth = \"radius [config=$radcliConfDir/radiusclient.conf,groupconfig=true]\"" /etc/ocserv/ocserv.conf
    sed -i "1i acct = \"radius [config=$radcliConfDir/radiusclient.conf,groupconfig=true]\"" /etc/ocserv/ocserv.conf

    curl -4 https://raw.githubusercontent.com/imafaz/ocserv/main/confs/radiusclient.conf -o $radcliConfDir/radiusclient.conf
    sed -i "s/ibsng_ip/$ibsng_ip/g" $radcliConfDir/radiusclient.conf
    curl -4 https://raw.githubusercontent.com/imafaz/ocserv/main/confs/servers -o $radcliConfDir/servers
    sed -i "s/ibsng_ip/$ibsng_ip/g" $radcliConfDir/servers
    sed -i "s/ibsng_secret/$ibsng_secret/g" $radcliConfDir/servers
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

systemctl enable ocserv
systemctl start ocserv

echo "Installation successful. Connect using:"
echo "$domain:$ocserv_port"
