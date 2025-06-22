#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_DIR="${SCRIPT_DIR}/../proxy"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function: Check environment
function check_environment() {
  # Check if we're in a Nix environment
  if [ -z "$IN_NIX_SHELL" ]; then
    echo -e "${RED}Error: Please enter Nix environment with 'nix develop' first${NC}"
    exit 1
  fi
  
  # Check if docker/podman is available
  if ! command -v docker &> /dev/null && ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: docker/podman is not installed or not in PATH${NC}"
    exit 1
  fi
}

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Optimize the nginx proxy configuration based on benchmark results."
  echo ""
  echo "Options:"
  echo "  -c, --cpu NUM        Number of CPU cores to optimize for (default: auto-detect)"
  echo "  -m, --memory SIZE    Memory size in MB to optimize for (default: auto-detect)"
  echo "  -l, --level LEVEL    Optimization level (1-3, default: 2)"
  echo "                       1: Conservative, 2: Balanced, 3: Aggressive"
  echo "  -h, --help           Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --cpu 4 --memory 2048 --level 2"
  echo "  $0 --level 3"
}

# Function: Parse arguments
function parse_arguments() {
  # Default values
  CPU_CORES=$(nproc 2>/dev/null || echo 2)
  MEMORY_MB=$(free -m | awk '/^Mem:/{print $2}' 2>/dev/null || echo 1024)
  OPT_LEVEL=2
  
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -c|--cpu)
        CPU_CORES="$2"
        shift 2
        ;;
      -m|--memory)
        MEMORY_MB="$2"
        shift 2
        ;;
      -l|--level)
        OPT_LEVEL="$2"
        shift 2
        ;;
      -h|--help)
        display_help
        exit 0
        ;;
      *)
        echo "Unknown parameter: $1"
        display_help
        exit 1
        ;;
    esac
  done
  
  # Validate optimization level
  if [[ "$OPT_LEVEL" != [1-3] ]]; then
    echo -e "${RED}Error: Optimization level must be 1, 2, or 3${NC}"
    display_help
    exit 1
  fi
  
  echo "Optimizing for $CPU_CORES CPU cores, $MEMORY_MB MB memory, level $OPT_LEVEL"
}

# Function: Backup current configuration
function backup_configuration() {
  echo "Backing up current configuration..."
  
  # Create backup directory
  BACKUP_DIR="${PROXY_DIR}/backups/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  
  # Backup nginx.conf
  cp "${PROXY_DIR}/nginx.conf" "${BACKUP_DIR}/nginx.conf"
  
  # Backup SSL settings
  cp "${PROXY_DIR}/conf.d/ssl-settings.conf" "${BACKUP_DIR}/ssl-settings.conf"
  
  echo -e "${GREEN}Configuration backed up to ${BACKUP_DIR}${NC}"
}

# Function: Optimize worker processes and connections
function optimize_workers() {
  echo "Optimizing worker processes and connections..."
  
  # Calculate optimal worker processes
  # Usually set to number of CPU cores
  WORKER_PROCESSES=$CPU_CORES
  
  # Calculate worker connections based on memory
  # Rule of thumb: 1024 connections per GB of RAM
  WORKER_CONNECTIONS=$(( $MEMORY_MB / 1024 * 1024 ))
  
  # Ensure minimum of 1024 connections
  if [ "$WORKER_CONNECTIONS" -lt 1024 ]; then
    WORKER_CONNECTIONS=1024
  fi
  
  # Apply more aggressive settings based on optimization level
  if [ "$OPT_LEVEL" -eq 3 ]; then
    WORKER_CONNECTIONS=$(( $WORKER_CONNECTIONS * 2 ))
  elif [ "$OPT_LEVEL" -eq 1 ]; then
    WORKER_CONNECTIONS=$(( $WORKER_CONNECTIONS / 2 ))
  fi
  
  # Update nginx.conf with new worker settings
  sed -i "s/worker_processes\s*[0-9a-z]*;/worker_processes $WORKER_PROCESSES;/" "${PROXY_DIR}/nginx.conf"
  
  # Find the events block and update worker_connections
  sed -i "/events {/,/}/{s/worker_connections\s*[0-9]*;/worker_connections $WORKER_CONNECTIONS;/}" "${PROXY_DIR}/nginx.conf"
  
  echo -e "${GREEN}Worker processes set to $WORKER_PROCESSES${NC}"
  echo -e "${GREEN}Worker connections set to $WORKER_CONNECTIONS${NC}"
}

# Function: Optimize buffer sizes
function optimize_buffers() {
  echo "Optimizing buffer sizes..."
  
  # Calculate optimal buffer sizes based on memory
  # Rule of thumb: larger buffers for more memory
  if [ "$MEMORY_MB" -gt 4096 ]; then
    # High memory system
    CLIENT_BODY_BUFFER_SIZE="128k"
    CLIENT_MAX_BODY_SIZE="100m"
    CLIENT_HEADER_BUFFER_SIZE="4k"
    LARGE_CLIENT_HEADER_BUFFERS="4 8k"
  elif [ "$MEMORY_MB" -gt 2048 ]; then
    # Medium memory system
    CLIENT_BODY_BUFFER_SIZE="64k"
    CLIENT_MAX_BODY_SIZE="50m"
    CLIENT_HEADER_BUFFER_SIZE="2k"
    LARGE_CLIENT_HEADER_BUFFERS="2 4k"
  else
    # Low memory system
    CLIENT_BODY_BUFFER_SIZE="32k"
    CLIENT_MAX_BODY_SIZE="20m"
    CLIENT_HEADER_BUFFER_SIZE="1k"
    LARGE_CLIENT_HEADER_BUFFERS="2 2k"
  fi
  
  # Apply more aggressive settings based on optimization level
  if [ "$OPT_LEVEL" -eq 3 ]; then
    CLIENT_BODY_BUFFER_SIZE="256k"
    CLIENT_MAX_BODY_SIZE="200m"
    CLIENT_HEADER_BUFFER_SIZE="8k"
    LARGE_CLIENT_HEADER_BUFFERS="4 16k"
  elif [ "$OPT_LEVEL" -eq 1 ]; then
    CLIENT_BODY_BUFFER_SIZE="16k"
    CLIENT_MAX_BODY_SIZE="10m"
    CLIENT_HEADER_BUFFER_SIZE="1k"
    LARGE_CLIENT_HEADER_BUFFERS="2 1k"
  fi
  
  # Update nginx.conf with new buffer settings
  # Find the http block and add buffer settings if they don't exist
  if ! grep -q "client_body_buffer_size" "${PROXY_DIR}/nginx.conf"; then
    sed -i "/http {/a \    client_body_buffer_size $CLIENT_BODY_BUFFER_SIZE;\n    client_max_body_size $CLIENT_MAX_BODY_SIZE;\n    client_header_buffer_size $CLIENT_HEADER_BUFFER_SIZE;\n    large_client_header_buffers $LARGE_CLIENT_HEADER_BUFFERS;" "${PROXY_DIR}/nginx.conf"
  else
    # Update existing buffer settings
    sed -i "s/client_body_buffer_size\s*[0-9a-z]*;/client_body_buffer_size $CLIENT_BODY_BUFFER_SIZE;/" "${PROXY_DIR}/nginx.conf"
    sed -i "s/client_max_body_size\s*[0-9a-z]*;/client_max_body_size $CLIENT_MAX_BODY_SIZE;/" "${PROXY_DIR}/nginx.conf"
    sed -i "s/client_header_buffer_size\s*[0-9a-z]*;/client_header_buffer_size $CLIENT_HEADER_BUFFER_SIZE;/" "${PROXY_DIR}/nginx.conf"
    sed -i "s/large_client_header_buffers\s*[0-9 a-z]*;/large_client_header_buffers $LARGE_CLIENT_HEADER_BUFFERS;/" "${PROXY_DIR}/nginx.conf"
  fi
  
  echo -e "${GREEN}Buffer sizes optimized${NC}"
}

# Function: Optimize SSL/TLS settings
function optimize_ssl() {
  echo "Optimizing SSL/TLS settings..."
  
  # Backup SSL settings
  cp "${PROXY_DIR}/conf.d/ssl-settings.conf" "${PROXY_DIR}/conf.d/ssl-settings.conf.bak"
  
  # Update SSL settings based on optimization level
  if [ "$OPT_LEVEL" -eq 3 ]; then
    # Aggressive optimization
    cat > "${PROXY_DIR}/conf.d/ssl-settings.conf" << EOF
# SSL/TLS Configuration - Aggressive Optimization
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';

# SSL session settings
ssl_session_timeout 24h;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets on;
ssl_buffer_size 8k;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# DH parameters for DHE ciphersuites
ssl_dhparam /etc/nginx/dhparam.pem;

# HSTS (15768000 seconds = 6 months)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# Enable TLS 1.3 early data
ssl_early_data on;
EOF
  elif [ "$OPT_LEVEL" -eq 2 ]; then
    # Balanced optimization
    cat > "${PROXY_DIR}/conf.d/ssl-settings.conf" << EOF
# SSL/TLS Configuration - Balanced Optimization
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';

# SSL session settings
ssl_session_timeout 4h;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_buffer_size 4k;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 1.1.1.1 1.0.0.1 valid=300s;
resolver_timeout 5s;

# DH parameters for DHE ciphersuites
ssl_dhparam /etc/nginx/dhparam.pem;

# HSTS (15768000 seconds = 6 months)
add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload" always;
EOF
  else
    # Conservative optimization
    cat > "${PROXY_DIR}/conf.d/ssl-settings.conf" << EOF
# SSL/TLS Configuration - Conservative Optimization
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-CHACHA20-POLY1305';

# SSL session settings
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 1.1.1.1 1.0.0.1 valid=300s;
resolver_timeout 5s;

# DH parameters for DHE ciphersuites
ssl_dhparam /etc/nginx/dhparam.pem;

# HSTS (15768000 seconds = 6 months)
add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload" always;
EOF
  fi
  
  echo -e "${GREEN}SSL/TLS settings optimized${NC}"
}

# Function: Optimize keepalive settings
function optimize_keepalive() {
  echo "Optimizing keepalive settings..."
  
  # Calculate optimal keepalive settings based on memory and CPU
  # Rule of thumb: higher values for more resources
  if [ "$MEMORY_MB" -gt 4096 ] && [ "$CPU_CORES" -gt 4 ]; then
    # High resource system
    KEEPALIVE_TIMEOUT=65
    KEEPALIVE_REQUESTS=1000
  elif [ "$MEMORY_MB" -gt 2048 ] || [ "$CPU_CORES" -gt 2 ]; then
    # Medium resource system
    KEEPALIVE_TIMEOUT=30
    KEEPALIVE_REQUESTS=500
  else
    # Low resource system
    KEEPALIVE_TIMEOUT=15
    KEEPALIVE_REQUESTS=100
  fi
  
  # Apply more aggressive settings based on optimization level
  if [ "$OPT_LEVEL" -eq 3 ]; then
    KEEPALIVE_TIMEOUT=120
    KEEPALIVE_REQUESTS=10000
  elif [ "$OPT_LEVEL" -eq 1 ]; then
    KEEPALIVE_TIMEOUT=10
    KEEPALIVE_REQUESTS=50
  fi
  
  # Update nginx.conf with new keepalive settings
  sed -i "s/keepalive_timeout\s*[0-9]*;/keepalive_timeout $KEEPALIVE_TIMEOUT;/" "${PROXY_DIR}/nginx.conf"
  
  # Add keepalive_requests if it doesn't exist
  if ! grep -q "keepalive_requests" "${PROXY_DIR}/nginx.conf"; then
    sed -i "/keepalive_timeout/a \    keepalive_requests $KEEPALIVE_REQUESTS;" "${PROXY_DIR}/nginx.conf"
  else
    # Update existing keepalive_requests
    sed -i "s/keepalive_requests\s*[0-9]*;/keepalive_requests $KEEPALIVE_REQUESTS;/" "${PROXY_DIR}/nginx.conf"
  fi
  
  echo -e "${GREEN}Keepalive settings optimized${NC}"
}

# Function: Add file system optimizations
function optimize_filesystem() {
  echo "Adding file system optimizations..."
  
  # Update nginx.conf with file system optimizations
  if ! grep -q "open_file_cache" "${PROXY_DIR}/nginx.conf"; then
    sed -i "/http {/a \    open_file_cache max=1000 inactive=20s;\n    open_file_cache_valid 30s;\n    open_file_cache_min_uses 2;\n    open_file_cache_errors on;" "${PROXY_DIR}/nginx.conf"
  fi
  
  # Update existing sendfile, tcp_nopush, and tcp_nodelay settings
  sed -i "s/sendfile\s*[a-z]*;/sendfile on;/" "${PROXY_DIR}/nginx.conf"
  
  if ! grep -q "tcp_nopush" "${PROXY_DIR}/nginx.conf"; then
    sed -i "/sendfile/a \    tcp_nopush on;" "${PROXY_DIR}/nginx.conf"
  else
    sed -i "s/tcp_nopush\s*[a-z]*;/tcp_nopush on;/" "${PROXY_DIR}/nginx.conf"
  fi
  
  if ! grep -q "tcp_nodelay" "${PROXY_DIR}/nginx.conf"; then
    sed -i "/tcp_nopush/a \    tcp_nodelay on;" "${PROXY_DIR}/nginx.conf"
  else
    sed -i "s/tcp_nodelay\s*[a-z]*;/tcp_nodelay on;/" "${PROXY_DIR}/nginx.conf"
  fi
  
  echo -e "${GREEN}File system optimizations added${NC}"
}

# Function: Add rate limiting optimizations
function optimize_rate_limiting() {
  echo "Optimizing rate limiting settings..."
  
  # Calculate optimal rate limiting settings based on resources and optimization level
  if [ "$OPT_LEVEL" -eq 3 ]; then
    RATE_LIMIT="30r/s"
    BURST=50
  elif [ "$OPT_LEVEL" -eq 2 ]; then
    RATE_LIMIT="20r/s"
    BURST=30
  else
    RATE_LIMIT="10r/s"
    BURST=20
  fi
  
  # Update rate limiting zone in nginx.conf
  if grep -q "limit_req_zone" "${PROXY_DIR}/nginx.conf"; then
    sed -i "s/limit_req_zone.*rate=[0-9]*r\/s;/limit_req_zone \$binary_remote_addr zone=securitylimit:10m rate=$RATE_LIMIT;/" "${PROXY_DIR}/nginx.conf"
  fi
  
  # Update burst settings in domain configurations
  find "${PROXY_DIR}/conf.d/domains" -type f -name "*.conf" -exec sed -i "s/limit_req zone=securitylimit burst=[0-9]* nodelay;/limit_req zone=securitylimit burst=$BURST nodelay;/" {} \;
  
  echo -e "${GREEN}Rate limiting settings optimized${NC}"
}

# Function: Verify configuration
function verify_configuration() {
  echo "Verifying nginx configuration..."
  
  # Use docker to verify the configuration
  docker run --rm -v "${PROXY_DIR}/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "${PROXY_DIR}/conf.d:/etc/nginx/conf.d:ro" \
    nginx:alpine nginx -t
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Configuration verification failed${NC}"
    echo "Restoring backup..."
    cp "${BACKUP_DIR}/nginx.conf" "${PROXY_DIR}/nginx.conf"
    cp "${BACKUP_DIR}/ssl-settings.conf" "${PROXY_DIR}/conf.d/ssl-settings.conf"
    echo -e "${YELLOW}Original configuration restored${NC}"
    return 1
  else
    echo -e "${GREEN}Configuration verification passed${NC}"
    return 0
  fi
}

# Function: Apply configuration
function apply_configuration() {
  echo "Applying new configuration..."
  
  # Check if proxy container is running
  if docker ps | grep -q "nginx-proxy"; then
    docker exec nginx-proxy nginx -s reload
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to reload nginx configuration${NC}"
      return 1
    else
      echo -e "${GREEN}Nginx configuration reloaded successfully${NC}"
    fi
  else
    echo -e "${YELLOW}Proxy container is not running. Starting...${NC}"
    cd "${PROXY_DIR}" && docker-compose up -d
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to start proxy container${NC}"
      return 1
    else
      echo -e "${GREEN}Proxy container started with new configuration${NC}"
    fi
  fi
  
  return 0
}

# Function: Generate optimization report
function generate_report() {
  echo "Generating optimization report..."
  
  # Create report directory
  mkdir -p "${PROXY_DIR}/reports"
  
  # Generate report
  cat > "${PROXY_DIR}/reports/optimization_report.md" << EOF
# Nginx Proxy Optimization Report

## Optimization Parameters
- Date: $(date)
- CPU Cores: $CPU_CORES
- Memory: $MEMORY_MB MB
- Optimization Level: $OPT_LEVEL

## Applied Optimizations
- Worker Processes: $WORKER_PROCESSES
- Worker Connections: $WORKER_CONNECTIONS
- Keepalive Timeout: $KEEPALIVE_TIMEOUT
- Keepalive Requests: $KEEPALIVE_REQUESTS
- Rate Limit: $RATE_LIMIT
- Rate Limit Burst: $BURST

## SSL/TLS Settings
$(cat "${PROXY_DIR}/conf.d/ssl-settings.conf" | grep -v "#")

## Backup Location
Original configuration backed up to: ${BACKUP_DIR}

## Next Steps
1. Run \`tests/benchmark-proxy.sh\` to verify performance improvements
2. Monitor server resource usage during peak load
3. Fine-tune settings as needed based on real-world performance
EOF
  
  echo -e "${GREEN}Optimization report generated: ${PROXY_DIR}/reports/optimization_report.md${NC}"
}

# Main script execution
check_environment
parse_arguments "$@"
backup_configuration
optimize_workers
optimize_buffers
optimize_ssl
optimize_keepalive
optimize_filesystem
optimize_rate_limiting
verify_configuration

if [ $? -eq 0 ]; then
  apply_configuration
  generate_report
  echo -e "\n${GREEN}Proxy optimization completed successfully!${NC}"
  echo -e "${GREEN}See ${PROXY_DIR}/reports/optimization_report.md for details${NC}"
else
  echo -e "\n${RED}Proxy optimization failed. Original configuration restored.${NC}"
  exit 1
fi