#!/bin/bash

# Port Forwarding Script for Nginx Multi-Project Architecture
# This script sets up port forwarding from privileged ports 80/443 to non-privileged ports 8080/8443

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/port-forwarding.log"

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"

# Function: Log messages
function log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function: Handle errors
function handle_error() {
  log "ERROR: $1"
  exit 1
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  handle_error "This script must be run as root (sudo)"
fi

# Check if iptables is installed
if ! command -v iptables &> /dev/null; then
  handle_error "iptables is not installed. Please install it first."
fi

log "Setting up port forwarding for production environment..."

# Clear any existing rules for these ports
log "Removing any existing port forwarding rules..."
iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080 2>/dev/null
iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443 2>/dev/null

# Add port forwarding rules
log "Adding port forwarding rules: 80→8080, 443→8443..."
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

log "Port forwarding configured successfully"

# Make rules persistent
log "Making iptables rules persistent..."

# Method 1: netfilter-persistent (Debian/Ubuntu)
if command -v netfilter-persistent &> /dev/null; then
  netfilter-persistent save
  log "Rules saved permanently with netfilter-persistent"

# Method 2: iptables-save to file (Generic Linux)
elif [ -d "/etc/iptables" ] || mkdir -p /etc/iptables &> /dev/null; then
  iptables-save > /etc/iptables/rules.v4
  log "Rules saved to /etc/iptables/rules.v4"
  
  # Check if rules are loaded at boot
  if [ ! -f "/etc/network/if-pre-up.d/iptables-restore" ]; then
    cat > /etc/network/if-pre-up.d/iptables-restore << 'EOF'
#!/bin/sh
iptables-restore < /etc/iptables/rules.v4
exit 0
EOF
    chmod +x /etc/network/if-pre-up.d/iptables-restore
    log "Created boot-time restoration script at /etc/network/if-pre-up.d/iptables-restore"
  fi

# Method 3: systemd service
else
  log "Creating systemd service for persistent port forwarding..."
  
  cat > /etc/systemd/system/nginx-port-forward.service << 'EOF'
[Unit]
Description=Nginx Port Forwarding
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
ExecStart=/sbin/iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
ExecStop=/sbin/iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
ExecStop=/sbin/iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable nginx-port-forward
  systemctl start nginx-port-forward
  log "Systemd service created and enabled"
fi

log "Port forwarding setup complete. Traffic will be forwarded from:"
log "  - Port 80 → 8080"
log "  - Port 443 → 8443"
log "This enables external access to the Nginx proxy via standard HTTP/HTTPS ports" 