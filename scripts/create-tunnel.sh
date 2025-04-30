#!/bin/bash

# Helper script to create a Cloudflare Tunnel and prepare credentials file
# Run this script on one of your servers to create the tunnel and prepare the credentials

set -e

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

# Check if jq is installed (required for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "Installing jq for JSON parsing..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        else
            echo "Error: Couldn't install jq. Please install it manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install jq
    else
        echo "Error: Couldn't install jq. Please install it manually."
        exit 1
    fi
fi

# Check if the user is logged in
if [ ! -f ~/.cloudflared/cert.pem ]; then
    echo "You need to log in to Cloudflare first."
    cloudflared login
fi

# Display title
echo "=============================================="
echo "        Cloudflare Tunnel Creator Tool        "
echo "=============================================="

# Ask for the tunnel name
read -p "Enter a name for your tunnel: " TUNNEL_NAME

if [[ -z "$TUNNEL_NAME" ]]; then
    echo "Error: Tunnel name cannot be empty."
    exit 1
fi

# Check if tunnel with this name already exists
echo "Checking for existing tunnels..."
EXISTING_TUNNELS=$(cloudflared tunnel list -o json 2>/dev/null || echo "[]")

# Validate JSON
if ! echo "$EXISTING_TUNNELS" | jq empty &>/dev/null; then
    echo "Warning: Could not parse tunnel list. Will attempt to create a new tunnel."
    EXISTING_TUNNELS="[]"
fi

if echo "$EXISTING_TUNNELS" | jq -e ".[] | select(.name == \"$TUNNEL_NAME\")" &>/dev/null; then
    echo "A tunnel with the name '$TUNNEL_NAME' already exists."
    TUNNEL_ID=$(echo "$EXISTING_TUNNELS" | jq -r ".[] | select(.name == \"$TUNNEL_NAME\") | .id")
    echo "Using existing tunnel ID: $TUNNEL_ID"
    
    # Check if local credentials file exists
    if [ ! -f "files/${TUNNEL_ID}.json" ] && [ -f ~/.cloudflared/${TUNNEL_ID}.json ]; then
        echo "Copying existing credentials to project..."
        mkdir -p files
        cp ~/.cloudflared/${TUNNEL_ID}.json files/
    fi
else
    # Create the tunnel
    echo "Creating new tunnel '$TUNNEL_NAME'..."
    # Capture the entire output of the tunnel creation
    TUNNEL_OUTPUT=$(cloudflared tunnel create "$TUNNEL_NAME" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error creating tunnel: $TUNNEL_OUTPUT"
        exit 1
    fi
    
    echo "$TUNNEL_OUTPUT"
    
    # Extract the UUID tunnel ID using regex patterns
    # First try to find tunnelID=<uuid>
    TUNNEL_ID=$(echo "$TUNNEL_OUTPUT" | grep -o "tunnelID=[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}" | cut -d= -f2)
    
    # If not found, try to match "Created tunnel X with id <uuid>"
    if [ -z "$TUNNEL_ID" ]; then
        TUNNEL_ID=$(echo "$TUNNEL_OUTPUT" | grep -o "with id [a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}" | awk '{print $3}')
    fi
    
    # Last resort, try to find any UUID in the output
    if [ -z "$TUNNEL_ID" ]; then
        TUNNEL_ID=$(echo "$TUNNEL_OUTPUT" | grep -o "[a-f0-9]\{8\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{4\}-[a-f0-9]\{12\}")
    fi
    
    if [ -z "$TUNNEL_ID" ]; then
        echo "Error: Failed to extract tunnel ID from the output."
        echo "Please check the Cloudflare dashboard or run 'cloudflared tunnel list' to find your tunnel ID."
        exit 1
    fi
    
    echo "Successfully created tunnel with ID: $TUNNEL_ID"
fi

# Ask for domain
read -p "Enter your domain (e.g., example.com): " DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo "Error: Domain cannot be empty."
    exit 1
fi

# Check for existing DNS records for this domain that might point to other tunnels
echo "Checking for existing DNS records for *.$DOMAIN..."
DNS_ROUTES=$(cloudflared tunnel route dns list 2>/dev/null || echo "Failed to list DNS routes")
EXISTING_DNS=$(echo "$DNS_ROUTES" | grep -i "hostname=\"*.$DOMAIN\"" || echo "")

if [ ! -z "$EXISTING_DNS" ]; then
    echo "WARNING: Found existing DNS records for *.$DOMAIN:"
    echo "$EXISTING_DNS"
    
    # Check if it points to a different tunnel
    DNS_TUNNEL_ID=$(echo "$EXISTING_DNS" | grep -o "id=\"[^\"]*\"" | cut -d'"' -f2)
    
    if [ ! -z "$DNS_TUNNEL_ID" ] && [ "$DNS_TUNNEL_ID" != "$TUNNEL_ID" ]; then
        echo ""
        echo "CONFLICT DETECTED: The domain *.$DOMAIN is already pointing to a different tunnel!"
        echo "Current DNS points to tunnel: $DNS_TUNNEL_ID"
        echo "You're trying to use tunnel: $TUNNEL_ID"
        echo ""
        echo "Options:"
        echo "1. Use a different domain"
        echo "2. Delete the existing DNS record with: cloudflared tunnel route dns delete *.$DOMAIN"
        echo "3. Use the tunnel with ID $DNS_TUNNEL_ID instead"
        echo ""
        read -p "Do you want to override the existing DNS record? (y/N): " OVERRIDE
        
        if [[ ! "$OVERRIDE" =~ ^[Yy]$ ]]; then
            echo "Aborting DNS setup. You can still use the tunnel, but you'll need to manually set up DNS."
            USE_DNS=false
        else
            echo "Will override existing DNS record..."
            USE_DNS=true
        fi
    else
        echo "The existing DNS record already points to this tunnel or couldn't determine the target tunnel."
        echo "Will attempt to update it..."
        USE_DNS=true
    fi
else
    echo "No existing DNS records found for *.$DOMAIN."
    USE_DNS=true
fi

# Create DNS CNAME records (idempotent - Cloudflare will update if exists)
if [ "$USE_DNS" = true ]; then
    echo "Creating/updating DNS CNAME record for *.$DOMAIN..."
    DNS_RESULT=$(cloudflared tunnel route dns "$TUNNEL_ID" "*.$DOMAIN" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error creating DNS record: $DNS_RESULT"
        
        if [[ "$DNS_RESULT" == *"is neither the ID nor the name of any of your tunnels"* ]]; then
            echo ""
            echo "The script couldn't find a tunnel with ID $TUNNEL_ID."
            echo "This sometimes happens immediately after tunnel creation."
            echo ""
            echo "Please wait a few seconds and try running the following command manually:"
            echo "  cloudflared tunnel route dns $TUNNEL_ID *.$DOMAIN"
            
            # Try to verify if the tunnel exists
            echo ""
            echo "Verifying tunnel existence..."
            cloudflared tunnel list | grep -i "$TUNNEL_ID" || echo "Tunnel $TUNNEL_ID not found in tunnel list."
        fi
        
        echo ""
        echo "Despite this error, you can still continue with the setup."
    else
        echo "DNS record successfully created/updated."
    fi
fi

# Check if credentials file exists locally before copying
if [ ! -f "files/${TUNNEL_ID}.json" ]; then
    # Check if it exists in cloudflared directory
    if [ -f ~/.cloudflared/${TUNNEL_ID}.json ]; then
        # Copy the credentials file to the files directory
        mkdir -p files
        cp ~/.cloudflared/${TUNNEL_ID}.json files/
        echo "Credentials file copied to files/${TUNNEL_ID}.json"
    else
        echo "Warning: Credentials file not found at ~/.cloudflared/${TUNNEL_ID}.json"
        echo "You may need to fetch it manually or check the Cloudflare dashboard."
        
        # Try to find any JSON files that might be the credentials
        POTENTIAL_FILES=$(find ~/.cloudflared -name "*.json" -type f -newer ~/.cloudflared/cert.pem 2>/dev/null | head -n 5)
        if [ ! -z "$POTENTIAL_FILES" ]; then
            echo "Found potential credential files:"
            echo "$POTENTIAL_FILES"
            echo "Try copying one of these files to files/${TUNNEL_ID}.json"
        fi
    fi
else
    echo "Credentials file already exists at files/${TUNNEL_ID}.json"
fi

# Verify final DNS setup
echo ""
echo "Verifying DNS setup..."
FINAL_DNS=$(cloudflared tunnel route dns list 2>/dev/null | grep -i "hostname=\"*.$DOMAIN\"" || echo "No DNS record found")
if [ ! -z "$FINAL_DNS" ]; then
    echo "Current DNS configuration for *.$DOMAIN:"
    echo "$FINAL_DNS"
    
    FINAL_TUNNEL_ID=$(echo "$FINAL_DNS" | grep -o "id=\"[^\"]*\"" | cut -d'"' -f2)
    if [ "$FINAL_TUNNEL_ID" = "$TUNNEL_ID" ]; then
        echo "✅ DNS is correctly configured to point to this tunnel."
    else
        echo "⚠️ Warning: DNS is pointing to tunnel $FINAL_TUNNEL_ID instead of $TUNNEL_ID"
    fi
else
    echo "⚠️ Warning: No DNS record found for *.$DOMAIN"
    echo "You may need to manually set up DNS after some time."
fi

# Display next steps
echo ""
echo "=============================================="
echo "        Tunnel Setup Complete                 "
echo "=============================================="
echo ""
echo "Tunnel Name: $TUNNEL_NAME"
echo "Tunnel ID:   $TUNNEL_ID"
echo "Domain:      *.$DOMAIN"
echo ""
echo "Next Steps:"
echo "1. Update your group_vars/all.yml with the following values:"
echo "   domain: \"$DOMAIN\""
echo "   tunnel_id: \"$TUNNEL_ID\""
echo ""
echo "2. Run the Ansible playbook to deploy your infrastructure:"
echo "   ansible-playbook playbook.yml"
echo ""
echo "3. Access your services at:"
echo "   https://hello.$DOMAIN (example test service)"
echo "   https://portainer.$DOMAIN (container management)"
echo "   https://traefik.$DOMAIN (reverse proxy dashboard)"
echo "==============================================" 