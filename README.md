# OCServ (OpenConnect) Installation Script

## Overview
The OCServ Installation Script is designed to simplify the installation and configuration of the OpenConnect VPN server (OCServ) with IBSNG Radius support on CentOS 7 systems.

## Installation Guide

### Prerequisites
- **Operating System**: CentOS 7
- **User Privileges**: Root access is required for installation.

### Quick Setup Steps
To quickly install and configure OCServ on your CentOS 7 system, follow these steps using the `install.sh` script:

1. **Run the Installation Command**:
   ```bash
   bash <(curl -s https://raw.githubusercontent.com/imafaz/ocserv/main/install.sh)
   ```

2. **Connect to Your OCServ Server**:
   After installation, you can connect to your OCServ server using the following address:
   ```
   https://your-domain:your-port
   ```

### IBSNG Installation
To install IBSNG, please refer to the repository available at:
[https://github.com/imafaz/IBSng](https://github.com/imafaz/IBSng)

Follow the instructions provided in the repository for detailed installation steps.

## License
This project is licensed under the MIT License. For more information, please refer to the [LICENSE](LICENSE) file.