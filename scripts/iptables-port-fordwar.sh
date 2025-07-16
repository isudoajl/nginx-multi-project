#!/bin/bash

# Script to apply iptables port redirects and make them persistent
# Redirects: 80 -> 8080, 443 -> 8443

set -e  # Exit on any error

echo "=== Applying iptables Port Redirect Rules ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Function to check if rule already exists
check_rule_exists() {
    local table="$1"
    local chain="$2" 
    local rule="$3"
    
    iptables -t "$table" -C "$chain" $rule 2>/dev/null
}

echo "1. Applying redirect rules..."

# HTTP redirects (80 -> 8080)
echo "   Adding HTTP redirect rules (80 -> 8080)..."

if ! check_rule_exists "nat" "PREROUTING" "-p tcp --dport 80 -j REDIRECT --to-port 8080"; then
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
    echo "   ✓ PREROUTING HTTP redirect added"
else
    echo "   ℹ PREROUTING HTTP redirect already exists"
fi

if ! check_rule_exists "nat" "OUTPUT" "-p tcp --dport 80 -j REDIRECT --to-port 8080"; then
    iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-port 8080
    echo "   ✓ OUTPUT HTTP redirect added"
else
    echo "   ℹ OUTPUT HTTP redirect already exists"
fi

# HTTPS redirects (443 -> 8443)
echo "   Adding HTTPS redirect rules (443 -> 8443)..."

if ! check_rule_exists "nat" "PREROUTING" "-p tcp --dport 443 -j REDIRECT --to-port 8443"; then
    iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
    echo "   ✓ PREROUTING HTTPS redirect added"
else
    echo "   ℹ PREROUTING HTTPS redirect already exists"
fi

if ! check_rule_exists "nat" "OUTPUT" "-p tcp --dport 443 -j REDIRECT --to-port 8443"; then
    iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-port 8443
    echo "   ✓ OUTPUT HTTPS redirect added"
else
    echo "   ℹ OUTPUT HTTPS redirect already exists"
fi

echo
echo "2. Making rules persistent..."

# Detect the distribution
if [ -f /etc/debian_version ]; then
    echo "   Detected Debian/Ubuntu system"
    
    # Install iptables-persistent if not installed
    if ! dpkg -l iptables-persistent >/dev/null 2>&1; then
        echo "   Installing iptables-persistent..."
        apt update
        DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
    fi
    
    # Create directory if it doesn't exist
    mkdir -p /etc/iptables
    
    # Save rules
    echo "   Saving iptables rules..."
    iptables-save | tee /etc/iptables/rules.v4 > /dev/null
    ip6tables-save | tee /etc/iptables/rules.v6 > /dev/null
    
    # Use netfilter-persistent service
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
        systemctl enable netfilter-persistent
        echo "   ✓ Rules saved using netfilter-persistent"
    fi
    
elif [ -f /etc/redhat-release ]; then
    echo "   Detected Red Hat/CentOS/Fedora system"
    
    # Save rules for Red Hat family
    if command -v service >/dev/null 2>&1; then
        service iptables save
    else
        iptables-save > /etc/sysconfig/iptables
    fi
    echo "   ✓ Rules saved to /etc/sysconfig/iptables"
    
else
    echo "   Unknown distribution, using manual method..."
    
    # Manual method - create systemd service
    iptables-save > /etc/iptables.rules
    
    # Create systemd service
    cat > /etc/systemd/system/iptables-restore.service << EOF
[Unit]
Description=Restore iptables rules
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables.rules
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable iptables-restore.service
    echo "   ✓ Created systemd service for iptables restore"
fi

echo
echo "3. Verifying rules..."

echo "   Current NAT table rules:"
iptables -t nat -L -n --line-numbers | grep -E "(REDIRECT|Chain)"

echo
echo "=== Setup Complete ==="
echo "✓ Port redirects applied:"
echo "  - HTTP  (80)  -> 8080"
echo "  - HTTPS (443) -> 8443"
echo "✓ Rules made persistent (will survive reboot)"
echo
echo "Test the setup:"
echo "  curl -v http://localhost:80"
echo "  curl -v https://localhost:443"
echo
echo "To remove these rules later, run:"
echo "  sudo iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080"
echo "  sudo iptables -t nat -D OUTPUT -p tcp --dport 80 -j REDIRECT --to-port 8080"
echo "  sudo iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443"
echo "  sudo iptables -t nat -D OUTPUT -p tcp --dport 443 -j REDIRECT --to-port 8443"
