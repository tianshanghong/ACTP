# Ansible Docker + Cloudflare Tunnel + Traefik + Portainer

This Ansible playbook automates the deployment of a Docker-based infrastructure with:
- **Traefik** for reverse proxy and automatic TLS certificate management
- **Cloudflare Tunnel** for secure, encrypted connections without exposing ports to the internet
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

## Repository Structure

This repository has been organized into the following directories:

```
.
├── ansible.cfg            # Ansible configuration file
├── docs/                  # Documentation files
├── examples/              # Example configuration files
├── files/                 # Files used by Ansible (tunnel credentials)
├── group_vars/            # Variables for Ansible groups
├── playbook.yml           # Main Ansible playbook
├── requirements.yml       # Ansible Galaxy requirements
├── roles/                 # Ansible roles
└── scripts/               # Utility scripts
```

For detailed information about the repository structure, see [docs/STRUCTURE.md](docs/STRUCTURE.md).

## Prerequisites

1. A Cloudflare account with your domain
2. Cloudflare API token with Zone:DNS:Edit permissions
3. Cloudflare Tunnel created and credentials downloaded
4. Bare metal servers with SSH access
5. Ansible ≥ 2.10 on your control machine
6. Compatible bcrypt Python package (see Compatibility Notes section)

You can check if your system meets the prerequisites by running:

```bash
./scripts/check-prereqs.sh
```

## Quick Start

For detailed installation instructions, see [docs/INSTALLATION.md](docs/INSTALLATION.md).

```bash
# Clone repository
git clone https://github.com/tianshanghong/metal
cd metal

# Check prerequisites
./scripts/check-prereqs.sh

# Install Ansible requirements
ansible-galaxy collection install -r requirements.yml

# Configure (copy from examples)
cp examples/inventory.ini.template inventory.ini
cp examples/all.yml.template group_vars/all.yml

# Edit configuration files
nano inventory.ini
nano group_vars/all.yml

# Create Cloudflare Tunnel or copy credentials
./scripts/create-tunnel.sh
# OR
cp ~/.cloudflared/<TUNNEL_ID>.json files/

# Run playbook
ansible-playbook playbook.yml
```

## Adding New Services

To add a new service, use Docker Compose and add these labels:

```yaml
services:
  myapp:
    image: myapp:latest
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=le"
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"

networks:
  traefik_network:
    external: true
```

The `networks` section is required to connect your service to the existing Traefik network, and the `external: true` property ensures Docker uses the pre-existing network rather than creating a new one.

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
- Secure password handling:
  - Traefik dashboard uses SHA-512 hashed passwords
  - Portainer uses bcrypt hashed passwords set at container startup

## Customization

- Modify the Traefik configuration in `roles/traefik/templates/traefik-compose.yml.j2`
- Adjust Cloudflare Tunnel settings in `roles/cloudflared/templates/config.yml.j2`
- Customize Portainer in `roles/portainer/templates/portainer-compose.yml.j2`

## Compatibility Notes

### bcrypt Python Module
This playbook uses bcrypt for password hashing. Some versions of the bcrypt Python module (including version 4.0.0+) may cause compatibility issues with Ansible's password hashing functionality. If you encounter this error:

```
AttributeError: module 'bcrypt' has no attribute '__about__'
```

The included `scripts/bcrypt_patch.py` script can automatically fix this issue:

```bash
# Fix bcrypt compatibility issues
python3 scripts/bcrypt_patch.py
```

#### Script Features
- **Auto-detection**: Automatically finds your Ansible Python environment
- **Non-invasive**: Only patches what's necessary
- **Safe**: Validates if the patch is needed before applying
- **Flexible**: Command-line options for custom configurations

#### Advanced Options
```bash
# Specify a custom Ansible Python path
python3 scripts/bcrypt_patch.py --path /path/to/ansible/python/site-packages

# Check if patch is needed without applying it
python3 scripts/bcrypt_patch.py --check

# Force patching even if it seems already applied
python3 scripts/bcrypt_patch.py --force

# Show help
python3 scripts/bcrypt_patch.py --help
```

#### Alternative Solutions
If you prefer not to use the patch script:

1. **Install a compatible version of bcrypt**:
   ```bash
   pip install bcrypt==3.2.0
   ```

2. **Use a different hashing method**:
   Modify the playbook to use SHA-512 or other hash types instead of bcrypt where possible.

### Docker Compose Variable Interpolation
If you see warnings about undefined variables in Docker Compose:
```
The "apr1" variable is not set. Defaulting to a blank string.
```

This is normal when using password hashes with $ symbols. Our templates automatically escape these characters.

## Troubleshooting

### Password Management
- For Traefik dashboard authentication, passwords are hashed using SHA-512
- For Portainer, passwords are hashed using bcrypt with proper escaping for Docker Compose
- Password hashing is done locally on the Ansible controller for security

### Common Issues
- If bcrypt hashing fails, ensure you have the correct version installed (see Compatibility Notes)
- For Docker Compose errors, check that your Docker version is compatible (20.10.0+)
- For DNS issues, verify that your Cloudflare API token has the correct permissions

## Notes for macOS Deployments

For macOS hosts, you may need to:
1. Comment out Linux-specific tasks 
2. Uncomment and adapt macOS-specific tasks in the role files
3. Install Docker Desktop for Mac manually or via Homebrew
