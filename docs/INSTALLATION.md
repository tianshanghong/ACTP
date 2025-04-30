# Installation Guide

This guide walks you through the process of deploying Docker with Traefik, Cloudflare Tunnel, and Portainer.

## Prerequisites

1. A Cloudflare account with your domain
2. Cloudflare API token with Zone:DNS:Edit permissions
3. Cloudflare Tunnel created and credentials downloaded
4. Bare metal servers with SSH access
5. Ansible ≥ 2.10 on your control machine
6. Compatible bcrypt Python package (see Compatibility Notes section in README)

## Setup Instructions

### 1. Clone this repository
```bash
git clone https://github.com/tianshanghong/metal
cd metal
```

### 2. Install Ansible requirements
```bash
ansible-galaxy collection install -r requirements.yml
```

### 3. Configure your inventory
Create your inventory file from the template:
```bash
cp examples/inventory.ini.template inventory.ini
```

Then edit `inventory.ini` to list your target servers:
```ini
[bare_metal]
server1 ansible_host=192.168.1.10 ansible_user=yourusername
server2 ansible_host=192.168.1.11 ansible_user=yourusername
```

### 4. Set your configuration
Create your configuration file from the template:
```bash
cp examples/all.yml.template group_vars/all.yml
```

Then edit `group_vars/all.yml` to set your domain and other parameters.

### 5. Prepare Cloudflare Tunnel credentials
Create the directory for tunnel credentials if it doesn't exist:
```bash
mkdir -p files
```

After creating a tunnel in Cloudflare, copy the credentials JSON file to:
```bash
cp ~/.cloudflared/<TUNNEL_ID>.json files/
```

Alternatively, you can use the included helper script to create a tunnel:
```bash
./scripts/create-tunnel.sh
```

### 6. Run the playbook
```bash
ansible-playbook playbook.yml
```

You'll be prompted for any missing credentials during playbook execution, including:
- Cloudflare API token (if not set in group_vars/all.yml)
- Cloudflare email (if not set in group_vars/all.yml)
- Tunnel ID (if not set in group_vars/all.yml)
- Traefik dashboard password
- Portainer admin password

## Post-Installation

1. Access Portainer at `https://portainer.yourdomain.com`
2. Test the Hello World service at `https://hello.yourdomain.com`
3. Add new services by using the appropriate Traefik labels

## Troubleshooting

If you encounter issues with bcrypt compatibility, use the included patch script:
```bash
python3 scripts/bcrypt_patch.py
```

For more detailed troubleshooting information, refer to the README. 