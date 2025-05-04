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

Then edit `group_vars/all.yml` to set your domains and other parameters:

```yaml
# List of all domains to be configured with Cloudflare Tunnel
# First domain will be used as default for services without explicit domain
domains:
  - domain: "example.com"
    zone_id: "your_zone_id_here"  # Find this in Cloudflare dashboard
  # For multiple domains, simply add more entries:
  # - domain: "anotherdomain.com"
  #   zone_id: "another_zone_id_here"  
```

The Zone ID can be found in your Cloudflare dashboard on the Overview page of each domain.

### 5. Prepare Cloudflare Tunnel credentials
You have two options:

#### Option A: Create a new tunnel
Use the included helper script to create a new tunnel:
```bash
./scripts/create-tunnel.sh
```

The script will:
1. Create a new Cloudflare Tunnel
2. Copy the credentials file to the files directory
3. Guide you through updating your configuration

> Note: The script only creates the tunnel. DNS records will be managed by Ansible.

#### Option B: Use an existing tunnel
If you already have a tunnel, copy its credentials file:
```bash
# Create the directory if it doesn't exist
mkdir -p files

# Copy the credentials file
cp ~/.cloudflared/<TUNNEL_ID>.json files/
```

### 6. Run the playbook
```bash
ansible-playbook playbook.yml
```

The playbook will:
1. Install and configure Docker
2. Deploy Traefik and set up TLS
3. Configure the Cloudflare Tunnel 
4. Create DNS records in Cloudflare for all your domains
5. Deploy Portainer for container management

You'll be prompted for any missing credentials during playbook execution, including:
- Cloudflare API token (if not set in group_vars/all.yml)
- Cloudflare email (if not set in group_vars/all.yml)
- Tunnel ID (if not set in group_vars/all.yml)
- Traefik dashboard password
- Portainer admin password

## Post-Installation

1. Access Portainer at `https://portainer.example.com` (replace example.com with your domain)
2. Test the Hello World service at `https://hello.example.com`
3. Add new services by using the appropriate Traefik labels

When using multiple domains, simply specify the domain in your service's Host rule:

```yaml
services:
  myapp:
    # ... configuration ...
    labels:
      - "traefik.http.routers.myapp.rule=Host(`app.example.com`)"
      # ... other labels ...
  
  another-app:
    # ... configuration ...
    labels:
      - "traefik.http.routers.another-app.rule=Host(`site.anotherdomain.com`)"
      # ... other labels ...
```

Remember that each router name must be unique across all your services.

### Removing a Tunnel

To properly remove a Cloudflare Tunnel:

1. Run the deletion script:
   ```bash
   ./scripts/delete-tunnel.sh
   ```
   
2. Remove the tunnel from your `group_vars/all.yml` configuration or replace it with a new tunnel ID

3. Run the Ansible playbook to update your infrastructure:
   ```bash
   ansible-playbook playbook.yml
   ```
   
This ensures that both the tunnel is deleted and all DNS records are properly updated.

## Troubleshooting

If you encounter issues with bcrypt compatibility, use the included patch script:
```bash
python3 scripts/bcrypt_patch.py
```

For more detailed troubleshooting information, refer to the README. 