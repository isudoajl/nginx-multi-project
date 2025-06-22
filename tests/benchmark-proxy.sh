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
  
  # Check if ab (Apache Benchmark) is available
  if ! command -v ab &> /dev/null; then
    echo -e "${RED}Error: Apache Benchmark (ab) is not installed or not in PATH${NC}"
    echo -e "${YELLOW}Please install it with: apk add apache2-utils${NC}"
    exit 1
  fi
}

# Function: Setup test environment
function setup_test_environment() {
  echo "Setting up test environment..."
  
  # Navigate to proxy directory
  cd "${PROXY_DIR}"
  
  # Check if docker-compose.yml exists
  if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found${NC}"
    return 1
  fi
  
  # Create test project for benchmarking
  mkdir -p "${SCRIPT_DIR}/tmp/benchmark"
  
  # Create docker-compose.yml for test project
  cat > "${SCRIPT_DIR}/tmp/benchmark/docker-compose.yml" << EOF
version: '3'

services:
  benchmark:
    image: nginx:alpine
    container_name: test-benchmark
    networks:
      - proxy-network
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html
      - ./nginx.conf:/etc/nginx/nginx.conf:ro

networks:
  proxy-network:
    external: true
    name: proxy-network
EOF

  # Create optimized nginx.conf for the test container
  cat > "${SCRIPT_DIR}/tmp/benchmark/nginx.conf" << EOF
user nginx;
worker_processes auto;
worker_rlimit_nofile 65535;

error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    multi_accept on;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log off;
    error_log /var/log/nginx/error.log crit;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 100000;
    types_hash_max_size 2048;
    server_tokens off;

    open_file_cache max=200000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    gzip on;
    gzip_min_length 10240;
    gzip_comp_level 1;
    gzip_vary on;
    gzip_proxied any;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/x-javascript application/xml;
    gzip_disable "MSIE [1-6]\.";

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        
        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files \$uri \$uri/ =404;
        }
    }
}
EOF

  # Create test content (10KB HTML file)
  echo "<html><head><title>Benchmark Test</title></head><body>" > "${SCRIPT_DIR}/tmp/benchmark/index.html"
  for i in {1..500}; do
    echo "<div>Benchmark test content line $i</div>" >> "${SCRIPT_DIR}/tmp/benchmark/index.html"
  done
  echo "</body></html>" >> "${SCRIPT_DIR}/tmp/benchmark/index.html"
  
  # Create domain configuration for the benchmark
  cat > "${PROXY_DIR}/conf.d/domains/benchmark.local.conf" << EOF
# Domain configuration for benchmark.local
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name benchmark.local;
    
    # Include SSL settings
    include /etc/nginx/conf.d/ssl-settings.conf;
    
    # SSL certificates
    ssl_certificate /etc/nginx/certs/test.local/cert.pem;
    ssl_certificate_key /etc/nginx/certs/test.local/cert-key.pem;
    
    # Include security headers
    include /etc/nginx/conf.d/security-headers.conf;
    
    # Proxy to benchmark container
    location / {
        proxy_pass http://test-benchmark;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

  # Generate self-signed certificate if it doesn't exist
  if [ ! -d "${PROXY_DIR}/certs/test.local" ]; then
    mkdir -p "${PROXY_DIR}/certs/test.local"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "${PROXY_DIR}/certs/test.local/cert-key.pem" \
      -out "${PROXY_DIR}/certs/test.local/cert.pem" \
      -subj "/CN=test.local" \
      -addext "subjectAltName=DNS:test.local,DNS:benchmark.local"
  fi
  
  # Add hosts entry for benchmark.local
  if ! grep -q "benchmark.local" /etc/hosts; then
    echo "127.0.0.1 benchmark.local" | sudo tee -a /etc/hosts > /dev/null
  fi
  
  # Start proxy container
  echo "Starting proxy container..."
  cd "${PROXY_DIR}"
  docker-compose up -d --build
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start proxy container${NC}"
    return 1
  fi
  
  # Start benchmark container
  echo "Starting benchmark container..."
  cd "${SCRIPT_DIR}/tmp/benchmark"
  docker-compose up -d
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start benchmark container${NC}"
    return 1
  fi
  
  # Wait for containers to start
  echo "Waiting for containers to start..."
  sleep 5
  
  return 0
}

# Function: Run HTTP benchmark
function run_http_benchmark() {
  echo "Running HTTP benchmark..."
  
  # Run Apache Benchmark for HTTP
  echo "Testing HTTP performance (HTTP to HTTPS redirection)..."
  ab -n 1000 -c 100 -k http://benchmark.local/ > "${SCRIPT_DIR}/tmp/http_benchmark.txt" 2>&1
  
  # Extract results
  REQUESTS_PER_SECOND=$(grep "Requests per second" "${SCRIPT_DIR}/tmp/http_benchmark.txt" | awk '{print $4}')
  TIME_PER_REQUEST=$(grep "Time per request" "${SCRIPT_DIR}/tmp/http_benchmark.txt" | head -1 | awk '{print $4}')
  
  echo -e "${GREEN}HTTP Benchmark Results:${NC}"
  echo "Requests per second: $REQUESTS_PER_SECOND"
  echo "Time per request: $TIME_PER_REQUEST ms"
  
  # Check if performance meets requirements
  if (( $(echo "$REQUESTS_PER_SECOND > 100" | bc -l) )); then
    echo -e "${GREEN}HTTP performance is good (> 100 req/s)${NC}"
  else
    echo -e "${RED}HTTP performance is below target (< 100 req/s)${NC}"
  fi
}

# Function: Run HTTPS benchmark
function run_https_benchmark() {
  echo "Running HTTPS benchmark..."
  
  # Run Apache Benchmark for HTTPS
  echo "Testing HTTPS performance..."
  ab -n 1000 -c 100 -k -f TLS1.2 -H "Host: benchmark.local" https://benchmark.local/ > "${SCRIPT_DIR}/tmp/https_benchmark.txt" 2>&1
  
  # Extract results
  REQUESTS_PER_SECOND=$(grep "Requests per second" "${SCRIPT_DIR}/tmp/https_benchmark.txt" | awk '{print $4}')
  TIME_PER_REQUEST=$(grep "Time per request" "${SCRIPT_DIR}/tmp/https_benchmark.txt" | head -1 | awk '{print $4}')
  
  echo -e "${GREEN}HTTPS Benchmark Results:${NC}"
  echo "Requests per second: $REQUESTS_PER_SECOND"
  echo "Time per request: $TIME_PER_REQUEST ms"
  
  # Check if performance meets requirements
  if (( $(echo "$REQUESTS_PER_SECOND > 1000" | bc -l) )); then
    echo -e "${GREEN}HTTPS performance is excellent (> 1000 req/s)${NC}"
  elif (( $(echo "$REQUESTS_PER_SECOND > 500" | bc -l) )); then
    echo -e "${YELLOW}HTTPS performance is acceptable (> 500 req/s)${NC}"
  else
    echo -e "${RED}HTTPS performance is below target (< 500 req/s)${NC}"
  fi
}

# Function: Identify bottlenecks
function identify_bottlenecks() {
  echo "Identifying potential bottlenecks..."
  
  # Check CPU usage during benchmark
  echo "Checking CPU usage during benchmark..."
  docker stats --no-stream nginx-proxy > "${SCRIPT_DIR}/tmp/cpu_usage.txt"
  CPU_USAGE=$(grep "nginx-proxy" "${SCRIPT_DIR}/tmp/cpu_usage.txt" | awk '{print $3}')
  
  echo "CPU Usage: $CPU_USAGE"
  
  if (( $(echo "$CPU_USAGE > 80.0" | bc -l) )); then
    echo -e "${RED}High CPU usage detected (> 80%). Consider increasing CPU allocation.${NC}"
  fi
  
  # Check memory usage
  echo "Checking memory usage..."
  MEMORY_USAGE=$(grep "nginx-proxy" "${SCRIPT_DIR}/tmp/cpu_usage.txt" | awk '{print $4}')
  
  echo "Memory Usage: $MEMORY_USAGE"
  
  if [[ "$MEMORY_USAGE" == *"GiB"* ]]; then
    MEM_VALUE=$(echo $MEMORY_USAGE | sed 's/GiB//')
    if (( $(echo "$MEM_VALUE > 1.0" | bc -l) )); then
      echo -e "${RED}High memory usage detected (> 1 GiB). Consider increasing memory allocation.${NC}"
    fi
  fi
  
  # Check for connection errors
  echo "Checking for connection errors..."
  CONNECTION_ERRORS=$(grep "Failed requests" "${SCRIPT_DIR}/tmp/https_benchmark.txt" | awk '{print $3}')
  
  echo "Connection Errors: $CONNECTION_ERRORS"
  
  if [ "$CONNECTION_ERRORS" -gt 0 ]; then
    echo -e "${RED}Connection errors detected. Check network configuration and connection limits.${NC}"
  fi
  
  # Check for SSL handshake issues
  echo "Checking for SSL handshake issues..."
  SSL_ERRORS=$(grep -i "SSL" "${SCRIPT_DIR}/tmp/https_benchmark.txt" | wc -l)
  
  if [ "$SSL_ERRORS" -gt 0 ]; then
    echo -e "${RED}SSL handshake issues detected. Check SSL configuration.${NC}"
  fi
  
  echo -e "${GREEN}Bottleneck analysis complete.${NC}"
}

# Function: Generate performance report
function generate_performance_report() {
  echo "Generating performance report..."
  
  # Create report directory
  mkdir -p "${PROXY_DIR}/reports"
  
  # Generate report
  cat > "${PROXY_DIR}/reports/performance_report.md" << EOF
# Nginx Proxy Performance Report

## Test Environment
- Date: $(date)
- Hardware: $(uname -s) $(uname -m)
- Proxy Version: nginx $(docker exec nginx-proxy nginx -v 2>&1 | grep -o '[0-9.]*')

## HTTP Performance
$(cat "${SCRIPT_DIR}/tmp/http_benchmark.txt")

## HTTPS Performance
$(cat "${SCRIPT_DIR}/tmp/https_benchmark.txt")

## Bottleneck Analysis
- CPU Usage: $CPU_USAGE
- Memory Usage: $MEMORY_USAGE
- Connection Errors: $CONNECTION_ERRORS

## Recommendations
EOF
  
  # Add recommendations based on performance results
  if (( $(echo "$REQUESTS_PER_SECOND < 500" | bc -l) )); then
    echo "- Consider optimizing worker processes and connections" >> "${PROXY_DIR}/reports/performance_report.md"
    echo "- Review SSL settings to reduce handshake overhead" >> "${PROXY_DIR}/reports/performance_report.md"
  fi
  
  if [ "$CONNECTION_ERRORS" -gt 0 ]; then
    echo "- Increase connection limits in nginx configuration" >> "${PROXY_DIR}/reports/performance_report.md"
    echo "- Check for network issues between containers" >> "${PROXY_DIR}/reports/performance_report.md"
  fi
  
  if (( $(echo "$CPU_USAGE > 80.0" | bc -l) )); then
    echo "- Increase CPU allocation for the proxy container" >> "${PROXY_DIR}/reports/performance_report.md"
    echo "- Optimize nginx worker processes based on available CPUs" >> "${PROXY_DIR}/reports/performance_report.md"
  fi
  
  echo -e "${GREEN}Performance report generated: ${PROXY_DIR}/reports/performance_report.md${NC}"
}

# Function: Cleanup test environment
function cleanup_test_environment() {
  echo "Cleaning up test environment..."
  
  # Stop benchmark container
  cd "${SCRIPT_DIR}/tmp/benchmark"
  docker-compose down
  
  # Remove benchmark domain configuration
  rm -f "${PROXY_DIR}/conf.d/domains/benchmark.local.conf"
  
  # Reload proxy configuration
  docker exec nginx-proxy nginx -s reload
  
  # Remove temporary files
  rm -rf "${SCRIPT_DIR}/tmp"
  
  echo -e "${GREEN}Test environment cleaned up${NC}"
  return 0
}

# Function: Run all tests
function run_all_tests() {
  local FAILED=0
  
  setup_test_environment
  if [ $? -ne 0 ]; then
    FAILED=1
    echo -e "${RED}Skipping further tests due to setup failure${NC}"
    cleanup_test_environment
    return $FAILED
  fi
  
  run_http_benchmark
  run_https_benchmark
  identify_bottlenecks
  generate_performance_report
  
  cleanup_test_environment
  
  echo -e "\n${GREEN}Performance testing completed!${NC}"
  echo -e "${GREEN}See ${PROXY_DIR}/reports/performance_report.md for detailed results${NC}"
  return 0
}

# Main script execution
check_environment
run_all_tests
exit $?