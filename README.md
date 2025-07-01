# OCServ (OpenConnect) Installation Script

## Overview
The OCServ Installation Script simplifies installation and configuration of OpenConnect VPN server (OCServ) with optional IBSNG Radius support on CentOS, AlmaLinux, Debian, Ubuntu, and Rocky Linux systems.

## Installation Guide

### Prerequisites
- **Operating System**: CentOS, AlmaLinux, Debian, Ubuntu, Rocky Linux
- **User Privileges**: Root access required.

### Quick Setup Steps
Run this command to start the installation:

```bash
bash <(curl -s https://raw.githubusercontent.com/AfazTech/ocserv/main/install.sh)
```

Follow the prompts to enter:

* OCServ port (e.g. 443)
* Your domain name (e.g. vpn.example.com)
* Authentication method:

  * Local (ocpasswd)
  * Linux PAM
  * Radius with IBSNG (requires IBSNG IP and secret)

### After Installation

Connect to your OCServ server via:

https://your-domain:your-port

### IBSNG Radius Server

To install and configure IBSNG Radius server, visit:
[https://github.com/AfazTech/IBSng](https://github.com/AfazTech/IBSng)

Follow the repository's instructions to set up IBSNG properly.

## Notes

* The script disables firewalld/ufw and uses iptables with appropriate rules.
* SELinux must be disabled manually if active; the script will instruct you.
* iptables rules are flushed and replaced to avoid conflicts.
* IPv4 forwarding is enabled.
* Certificates are managed using certbot with manual DNS challenge.

## License

MIT License. See [LICENSE](LICENSE) for details.