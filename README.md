# Ansible Docker + Cloudflare Tunnel + Traefik + ExternalDNS + Portainer

This Ansible playbook automates the deployment of a Docker-based infrastructure with:
- **Traefik** for reverse proxy and automatic TLS certificate management
- **Cloudflare Tunnel** for secure, encrypted connections without exposing ports to the internet
- **External DNS** for automatic DNS record management
- **Portainer CE** for web-based Docker management

## Architecture Overview

This setup creates a secure, automated infrastructure where:
- Traffic flows through Cloudflare's network for security and performance
- Services are automatically assigned subdomains with valid TLS certificates
- No ports need to be exposed to the internet
- New services can be deployed by simply adding labels to containers

```
             Internet Users
                   |
           [DNS: *.example.com]
                   |
             Cloudflare CDN/WAF
                   |
        ┌──────────┴──────────┐
        │  Cloudflare Tunnel  │
        └──────────┬──────────┘
                   │ 
               cloudflared
                   │ 
                Traefik
                   │
             Docker Services
```

## Prerequisites

1. A Cloudflare account with your domain
2. Cloudflare API token with Zone:DNS:Edit permissions
3. Cloudflare Tunnel created and credentials downloaded
4. Bare metal servers with SSH access
5. Ansible ≥ 2.10 on your control machine

## Setup Instructions

### 1. Clone this repository
```bash
git clone https://github.com/yourusername/ansible-docker-cloudflare
cd ansible-docker-cloudflare
```

### 2. Configure your inventory
Create your inventory file from the template:
```bash
cp inventory.ini.template inventory.ini
```

Then edit `inventory.ini` to list your target servers:
```ini
[bare_metal]
server1 ansible_host=192.168.1.10 ansible_user=yourusername
server2 ansible_host=192.168.1.11 ansible_user=yourusername
```

### 3. Set your configuration
Create your configuration file from the template:
```bash
cp group_vars/all.yml.template group_vars/all.yml
```

Then edit `group_vars/all.yml` to set your domain and other parameters. You can leave credentials blank and you'll be prompted for them during playbook execution:

```yaml
domain: "yourdomain.com"
cf_api_token: ""  # Will be prompted for if empty
cf_email: ""      # Will be prompted for if empty
tunnel_id: ""     # Will be prompted for if empty
```

### 4. Prepare Cloudflare Tunnel credentials
Create the directory for tunnel credentials:
```bash
mkdir -p files
```

After creating a tunnel in Cloudflare, copy the credentials JSON file to:
```bash
cp ~/.cloudflared/<TUNNEL_ID>.json files/
```

Alternatively, you can use the included helper script to create a tunnel:
```bash
./create-tunnel.sh
```

### 5. Run the playbook
```bash
ansible-playbook playbook.yml
```

You'll be prompted for any missing credentials during playbook execution.

## Post-Installation

1. Access Portainer at `https://portainer.yourdomain.com`
2. Test the Hello World service at `https://hello.yourdomain.com`
3. Add new services by using the appropriate Traefik and ExternalDNS labels

## Adding New Services

To add a new service, use Docker Compose and add these labels:

```yaml
services:
  myapp:
    image: myapp:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=le"
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"
      - "external-dns.alpha.kubernetes.io/hostname=myapp.example.com."
```

## Security Notes

- No ports are exposed to the internet as all traffic flows through Cloudflare Tunnel
- All traffic is encrypted with TLS
- Cloudflare provides DDoS protection and WAF capabilities
- The setup minimizes attack surface by exposing only necessary services
- Sensitive files and credentials are excluded from version control:
  - Server information (`inventory.ini`)
  - API tokens and credentials (`group_vars/all.yml`)
  - Tunnel credentials (`files/*.json`)
- Interactive prompts are used to collect credentials securely during deployment
- Secure password handling for Traefik dashboard

## Customization

- Modify the Traefik configuration in `roles/traefik/templates/traefik-compose.yml.j2`
- Adjust Cloudflare Tunnel settings in `roles/cloudflared/templates/config.yml.j2`
- Update External DNS configuration in `roles/external_dns/templates/external-dns-compose.yml.j2`
- Customize Portainer in `roles/portainer/templates/portainer-compose.yml.j2`

## Notes for macOS Deployments

For macOS hosts, you may need to:
1. Comment out Linux-specific tasks 
2. Uncomment and adapt macOS-specific tasks in the role files
3. Install Docker Desktop for Mac manually or via Homebrew 