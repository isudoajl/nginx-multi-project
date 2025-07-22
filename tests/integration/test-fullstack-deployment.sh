#!/bin/bash

# Integration test for full-stack monorepo deployment

set -e

# Source test utilities and common functions
source "$(dirname "${BASH_SOURCE[0]}")/../test-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/create-project/modules/common.sh"

# Test configuration
TEST_PROJECT_NAME="test-fullstack"
TEST_DOMAIN="test-fullstack.local"
TEST_MONOREPO_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../test-fullstack-monorepo")"
TEST_BACKEND_PORT="3000"

function cleanup_test_environment() {
    log "Cleaning up test environment..."
    
    # Stop and remove containers
    podman stop "$TEST_PROJECT_NAME" 2>/dev/null || true
    podman rm "$TEST_PROJECT_NAME" 2>/dev/null || true
    
    # Remove networks
    podman network rm "${TEST_PROJECT_NAME}-network" 2>/dev/null || true
    
    # Remove project directory
    if [[ -d "$PROJECTS_DIR/$TEST_PROJECT_NAME" ]]; then
        rm -rf "$PROJECTS_DIR/$TEST_PROJECT_NAME"
    fi
    
    log "Test environment cleaned up"
}

function test_fullstack_project_creation() {
    print_test_header "Full-Stack Project Creation"
    
    # Create full-stack monorepo project
    "$SCRIPT_DIR/create-project-modular.sh" \
        --name "$TEST_PROJECT_NAME" \
        --domain "$TEST_DOMAIN" \
        --monorepo "$TEST_MONOREPO_DIR" \
        --frontend-dir frontend \
        --backend-dir backend \
        --backend-port "$TEST_BACKEND_PORT" \
        --env DEV
    
    # Verify project directory was created
    assert_directory_exists "$PROJECTS_DIR/$TEST_PROJECT_NAME" "Project directory should exist"
    
    # Verify required files were created
    assert_file_exists "$PROJECTS_DIR/$TEST_PROJECT_NAME/Dockerfile" "Dockerfile should exist"
    assert_file_exists "$PROJECTS_DIR/$TEST_PROJECT_NAME/docker-compose.yml" "docker-compose.yml should exist"
    assert_file_exists "$PROJECTS_DIR/$TEST_PROJECT_NAME/nginx.conf" "nginx.conf should exist"
    assert_file_exists "$PROJECTS_DIR/$TEST_PROJECT_NAME/start.sh" "start.sh should exist"
    assert_file_exists "$PROJECTS_DIR/$TEST_PROJECT_NAME/monorepo.env" "monorepo.env should exist"
    
    # Verify monorepo.env contains backend configuration
    assert_file_contains "$PROJECTS_DIR/$TEST_PROJECT_NAME/monorepo.env" "HAS_BACKEND=true" "monorepo.env should contain backend config"
    assert_file_contains "$PROJECTS_DIR/$TEST_PROJECT_NAME/monorepo.env" "BACKEND_SUBDIR=backend" "monorepo.env should contain backend subdir"
    assert_file_contains "$PROJECTS_DIR/$TEST_PROJECT_NAME/monorepo.env" "BACKEND_PORT=$TEST_BACKEND_PORT" "monorepo.env should contain backend port"
    assert_file_contains "$PROJECTS_DIR/$TEST_PROJECT_NAME/monorepo.env" "BACKEND_FRAMEWORK=rust" "monorepo.env should contain backend framework"
    
    # Verify nginx.conf contains backend proxy configuration
    assert_file_contains "$PROJECTS_DIR/$TEST_PROJECT_NAME/nginx.conf" "upstream backend" "nginx.conf should contain backend upstream"
    assert_file_contains "$PROJECTS_DIR/$TEST_PROJECT_NAME/nginx.conf" "location /api/" "nginx.conf should contain API location"
    assert_file_contains "$PROJECTS_DIR/$TEST_PROJECT_NAME/nginx.conf" "proxy_pass http://backend" "nginx.conf should contain backend proxy"
    
    # Verify Dockerfile contains multi-stage build for backend
    assert_file_contains "$PROJECTS_DIR/$TEST_PROJECT_NAME/Dockerfile" "backend-builder" "Dockerfile should contain backend builder stage"
    assert_file_contains "$PROJECTS_DIR/$TEST_PROJECT_NAME/Dockerfile" "cargo build --release" "Dockerfile should contain Rust build command"
    
    print_test_result "Full-Stack Project Creation" "PASSED"
}

function test_container_build_and_deployment() {
    print_test_header "Container Build and Deployment"
    
    # Build the container
    log "Building full-stack container..."
    cd "$PROJECTS_DIR/$TEST_PROJECT_NAME"
    
    # Check if Cargo.lock was generated
    if [[ -f "$TEST_MONOREPO_DIR/backend/Cargo.lock" ]]; then
        log "✅ Cargo.lock was generated automatically"
    else
        log "⚠️ Cargo.lock not found, this might cause build issues"
    fi
    
    # Build with podman
    podman build -t "$TEST_PROJECT_NAME" -f Dockerfile "$TEST_MONOREPO_DIR"
    
    log "Container built successfully"
    
    # Deploy using docker-compose
    log "Deploying full-stack container..."
    
    # Create networks first
    podman network create "${TEST_PROJECT_NAME}-network" 2>/dev/null || true
    podman network create "nginx-proxy-network" 2>/dev/null || true
    
    # Start the container
    podman run -d \
        --name "$TEST_PROJECT_NAME" \
        --network "${TEST_PROJECT_NAME}-network" \
        --network "nginx-proxy-network" \
        -p "8090:80" \
        -v "$PWD/nginx.conf:/etc/nginx/nginx.conf:ro" \
        -v "$PWD/conf.d:/etc/nginx/conf.d:ro" \
        -v "$PWD/logs:/var/log/nginx" \
        -v "$PWD/certs/cert.pem:/etc/ssl/certs/cert.pem:ro" \
        -v "$PWD/certs/cert-key.pem:/etc/ssl/private/cert-key.pem:ro" \
        -e "PROJECT_NAME=$TEST_PROJECT_NAME" \
        -e "DOMAIN_NAME=$TEST_DOMAIN" \
        -e "HAS_BACKEND=true" \
        -e "BACKEND_PORT=$TEST_BACKEND_PORT" \
        "$TEST_PROJECT_NAME"
    
    # Wait for container to start
    sleep 10
    
    # Verify container is running
    local container_status=$(podman ps --format "{{.Status}}" --filter "name=$TEST_PROJECT_NAME")
    assert_contains "$container_status" "Up" "Container should be running"
    
    print_test_result "Container Build and Deployment" "PASSED"
}

function test_frontend_connectivity() {
    print_test_header "Frontend Connectivity"
    
    # Test frontend HTTP connectivity
    log "Testing frontend HTTP response..."
    local frontend_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8090/ || echo "failed")
    assert_equals "$frontend_response" "200" "Frontend should return HTTP 200"
    
    # Test frontend content
    local frontend_content=$(curl -s http://localhost:8090/ | grep -o "Full-Stack Monorepo Test" || echo "not found")
    assert_equals "$frontend_content" "Full-Stack Monorepo Test" "Frontend should serve correct content"
    
    print_test_result "Frontend Connectivity" "PASSED"
}

function test_backend_connectivity() {
    print_test_header "Backend Connectivity"
    
    # Test backend health endpoint via nginx proxy
    log "Testing backend health endpoint..."
    local health_response=$(curl -s http://localhost:8090/api/health || echo "failed")
    assert_equals "$health_response" "OK" "Backend health endpoint should return OK"
    
    # Test backend status endpoint via nginx proxy
    log "Testing backend status endpoint..."
    local status_response=$(curl -s http://localhost:8090/api/status | jq -r '.status' 2>/dev/null || echo "failed")
    assert_equals "$status_response" "running" "Backend status endpoint should return running"
    
    # Test backend service info
    local service_info=$(curl -s http://localhost:8090/api/status | jq -r '.service' 2>/dev/null || echo "failed")
    assert_equals "$service_info" "test-backend" "Backend should identify as test-backend service"
    
    print_test_result "Backend Connectivity" "PASSED"
}

function test_service_communication() {
    print_test_header "Service Communication"
    
    # Test container logs for both services
    log "Checking container logs for multi-service startup..."
    local container_logs=$(podman logs "$TEST_PROJECT_NAME" 2>&1)
    
    # Check if both services started
    assert_contains "$container_logs" "Starting backend service" "Backend service should start"
    assert_contains "$container_logs" "Starting Nginx frontend service" "Nginx service should start"
    
    # Check if backend is listening on correct port
    assert_contains "$container_logs" "port $TEST_BACKEND_PORT" "Backend should listen on configured port"
    
    # Test internal service communication
    log "Testing internal service architecture..."
    local processes=$(podman exec "$TEST_PROJECT_NAME" ps aux || echo "failed")
    assert_contains "$processes" "nginx" "Nginx process should be running"
    assert_contains "$processes" "test-backend" "Backend process should be running"
    
    print_test_result "Service Communication" "PASSED"
}

function main() {
    print_section_header "Full-Stack Monorepo Deployment Integration Test"
    
    # Check if running in Nix environment
    if [[ -z "$IN_NIX_SHELL" ]]; then
        handle_error "This test must be run in a Nix development environment. Run: nix develop"
    fi
    
    # Cleanup any existing test environment
    cleanup_test_environment
    
    # Run tests
    test_fullstack_project_creation
    test_container_build_and_deployment
    test_frontend_connectivity
    test_backend_connectivity
    test_service_communication
    
    # Cleanup
    cleanup_test_environment
    
    print_section_header "Full-Stack Integration Test Summary"
    echo "✅ All full-stack integration tests passed!"
    echo "🎉 Phase 2 backend implementation is working correctly!"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
