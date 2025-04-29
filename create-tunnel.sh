#!/bin/bash

# Helper script to create a Cloudflare Tunnel and prepare credentials file
# Run this script on one of your servers to create the tunnel and prepare the credentials

# Ensure cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "cloudflared is not installed. Installing now..."
    
    # Check the OS and install accordingly
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -L --output cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install cloudflare/cloudflare/cloudflared
    else
        echo "Unsupported OS. Please install cloudflared manually."
        exit 1
    fi
fi

# Check if the user is logged in
if [ ! -f ~/.cloudflared/cert.pem ]; then
    echo "You need to log in to Cloudflare first."
    cloudflared login
fi

# Ask for the tunnel name
read -p "Enter a name for your tunnel: " TUNNEL_NAME

# Create the tunnel
echo "Creating tunnel '$TUNNEL_NAME'..."
TUNNEL_JSON=$(cloudflared tunnel create "$TUNNEL_NAME")
TUNNEL_ID=$(echo "$TUNNEL_JSON" | grep -o 'Created tunnel.*' | cut -d' ' -f3)

if [ -z "$TUNNEL_ID" ]; then
    echo "Failed to create tunnel. Please check the output above for errors."
    exit 1
fi

echo "Tunnel created with ID: $TUNNEL_ID"

# Ask for domain
read -p "Enter your domain (e.g., example.com): " DOMAIN

# Create DNS CNAME records
echo "Creating DNS CNAME record for *.$DOMAIN..."
cloudflared tunnel route dns "$TUNNEL_ID" "*.$DOMAIN"

# Copy the credentials file to the files directory
mkdir -p files
cp ~/.cloudflared/${TUNNEL_ID}.json files/

echo "
=================================================
Tunnel setup complete!

Tunnel ID: $TUNNEL_ID
Tunnel Name: $TUNNEL_NAME
Domain: *.$DOMAIN

Credentials file has been copied to files/${TUNNEL_ID}.json

Remember to update your group_vars/all.yml with:
- domain: $DOMAIN
- tunnel_id: $TUNNEL_ID

Then run: ansible-playbook playbook.yml
=================================================
" 