# Repository Structure

This repository contains an Ansible playbook for deploying Docker with Traefik, Cloudflare Tunnel, and Portainer. The repository is organized as follows:

## Directory Structure

```
.
├── ansible.cfg            # Ansible configuration file
├── docs/                  # Documentation files
├── examples/              # Example configuration files
├── files/                 # Files used by Ansible (like tunnel credentials)
├── group_vars/            # Variables for Ansible groups
├── playbook.yml           # Main Ansible playbook
├── requirements.yml       # Ansible Galaxy requirements
├── roles/                 # Ansible roles
│   ├── cloudflared/       # Role for Cloudflare Tunnel
│   ├── docker/            # Role for Docker installation
│   ├── portainer/         # Role for Portainer
│   └── traefik/           # Role for Traefik
└── scripts/               # Utility scripts
    ├── bcrypt_patch.py    # Script to fix bcrypt compatibility issues
    ├── check-prereqs.sh   # Script to check deployment prerequisites 
    ├── create-tunnel.sh   # Script to create a Cloudflare Tunnel
    └── delete-tunnel.sh   # Script to delete a Cloudflare Tunnel
```

## Key Components

### Main Playbook (playbook.yml)
The main Ansible playbook that orchestrates the deployment of all components.

### Roles
- **docker**: Installs Docker and Docker Compose
- **traefik**: Sets up Traefik as a reverse proxy with automatic TLS certificate management
- **cloudflared**: Configures Cloudflare Tunnel for secure connections
- **portainer**: Deploys Portainer for web-based Docker management

### Scripts
- **bcrypt_patch.py**: Fixes compatibility issues with the bcrypt Python module
- **check-prereqs.sh**: Checks if your system meets all the prerequisites for deployment
- **create-tunnel.sh**: Helper script to create a Cloudflare Tunnel
- **delete-tunnel.sh**: Helper script to delete a Cloudflare Tunnel

### Configuration
- **group_vars/all.yml**: Contains variables used by all hosts (from template)
- **inventory.ini**: Lists target servers for deployment (from template)
- **files/**: Directory for Cloudflare Tunnel credentials 