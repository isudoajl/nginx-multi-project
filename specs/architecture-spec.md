# Microservices Nginx Architecture Specification

## Overview
This document outlines the architecture for transforming the current monolithic nginx setup into a microservices-based architecture. Each project will run in its own isolated nginx container, orchestrated through a central nginx proxy, eliminating single points of failure and providing better isolation, scalability, and maintainability.

## Architecture Components

### Current State
- Single nginx server handling all projects
- Shared configuration files
- Single point of failure
- Limited isolation between projects

### Target State
1. **Nginx Proxy Container**
   - Acts as the entry point for all traffic
   - Routes requests to appropriate project containers
   - Handles SSL termination at the edge
   - Implements shared security policies
   - Uses IP-based routing for reliable connectivity

2. **Project-Specific Nginx Containers**
   - One container per project/domain
   - Isolated configuration and resources
   - Independent scaling and deployment
   - Project-specific security policies

3. **Container Orchestration**
   - Using Podman + Docker Compose
   - Centralized management of containers
   - Zero-downtime deployments
   - Health monitoring and automatic recovery
   - Network connectivity verification

4. **Certificate Management**
   - Flexible certificate location with sensible defaults
   - Support for both development (self-signed) and production certificates
   - Centralized or distributed certificate storage options
   - Domain-specific certificate mounting

## Network Architecture

```
                                  ┌─────────────────┐
                                  │                 │
                                  │  Load Balancer  │
                                  │   (Optional)    │
                                  │                 │
                                  └────────┬────────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                         Nginx Proxy Container                       │
│                                                                     │
└───────┬─────────────────────┬────────────────────┬─────────────────┘
        │                     │                    │
        ▼                     ▼                    ▼
┌───────────────┐     ┌───────────────┐    ┌───────────────┐
│               │     │               │    │               │
│  Project A    │     │  Project B    │    │  Project C    │
│  Container    │     │  Container    │    │  Container    │
│               │     │               │    │               │
└───────────────┘     └───────────────┘    └───────────────┘
```

## Container Network Isolation

Each project container operates on its own isolated network, with the proxy container being the only component with access to all project networks. This ensures:

1. Projects cannot directly communicate with each other
2. External access is controlled exclusively through the proxy
3. Security breaches in one project cannot affect others

### Advanced Network Topology (Implemented 2025-06-23)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   nginx-proxy   │    │   project-a     │    │   project-b     │
│   (Port 8080)   │◄──►│   (Port 8090)   │    │   (Port 8091)   │
│   (Port 8443)   │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └─────── nginx-proxy-network ──────────────────────┘
                         │                       │
            ┌─────────────────┐    ┌─────────────────┐
            │  project-a-net  │    │  project-b-net  │
            │   (Isolated)    │    │   (Isolated)    │
            └─────────────────┘    └─────────────────┘
```

**Key Features:**
- **Dual Network Membership**: Each project connects to both shared proxy network and isolated project network
- **Zero-Downtime Integration**: New projects can be added without disrupting existing services
- **Dynamic Network Management**: Automatic network creation and connection during deployment
- **IP-Based Routing**: Using container IP addresses for reliable proxy_pass directives
- **Network Connectivity Verification**: Pre-deployment verification of container connectivity

## Security Architecture

1. **Edge Security (Proxy Level)**
   - TLS termination
   - DDoS protection
   - Rate limiting
   - IP filtering
   - HTTP method restrictions
   - Bad bot blocking

2. **Project-Level Security**
   - Content Security Policy
   - X-Frame-Options
   - X-Content-Type-Options
   - Referrer Policy
   - Project-specific rate limits
   - Custom error handling

3. **Container Security**
   - Non-root user execution
   - Read-only filesystems where possible
   - Resource limits (CPU, memory)
   - Minimal base images
   - Secrets management

## Scalability Considerations

1. **Horizontal Scaling**
   - Multiple instances of project containers
   - Load balancing between instances
   - Session persistence options

2. **Vertical Scaling**
   - Resource allocation adjustments
   - Performance optimization
   - Caching strategies

## Monitoring and Observability

1. **Health Checks**
   - Container status monitoring
   - Endpoint availability checks
   - Certificate expiration monitoring
   - Network connectivity verification

2. **Logging**
   - Centralized log collection
   - Structured logging format
   - Log rotation and retention policies

3. **Metrics**
   - Request rate and latency
   - Error rates
   - Resource utilization

## Disaster Recovery

1. **Backup Strategy**
   - Configuration backups
   - Certificate backups
   - Automated backup scheduling

2. **Recovery Procedures**
   - Container recreation
   - Configuration restoration
   - Rollback capabilities
   - Self-healing infrastructure

## Integration Points

1. **Cloudflare Integration**
   - DNS management
   - WAF rules
   - Edge optimization
   - SSL/TLS configuration

2. **OAuth Integration**
   - Authentication service connectivity
   - Secure token handling
   - Authorization flows

## Deployment Workflow

### Standard Deployment (From Scratch)
1. Proxy infrastructure detection and creation
2. Project configuration generation
3. Container image building
4. Network setup
5. Container deployment
6. Proxy configuration update
7. Health verification
8. DNS updates (if applicable)

### Incremental Deployment (New Feature - 2025-06-23)
1. **Proxy Intelligence**: Automatic detection of existing proxy state
2. **Ecosystem Preservation**: Validation that existing projects remain untouched
3. **Dynamic Integration**: Seamless addition of new projects to running ecosystem
4. **Hot Configuration Updates**: Live proxy configuration reloading without downtime
5. **Comprehensive Verification**: End-to-end testing of new project integration
6. **IP-Based Routing**: Using container IP addresses for reliable proxy_pass directives
7. **Network Connectivity Verification**: Pre-deployment verification of container connectivity

**Deployment Capabilities:**
- **From-Scratch**: Complete infrastructure creation when no proxy exists
- **Incremental**: Adding projects to existing ecosystem without disruption
- **Self-Healing**: Automatic recovery from partial failures
- **Zero-Downtime**: Service continuity maintained throughout deployment process

## Critical Bug Fixes

1. **IP Address Detection Bug**: Fixed issue with concatenated network IP addresses in proxy_pass directives
2. **Network Name Template Parsing Bug**: Resolved podman inspect template parsing failures with network names containing hyphens
3. **Nginx Configuration Structure Bug**: Added proper nginx.conf structure with user, events, and http directives
4. **SSL Certificate Security Vulnerability**: Added comprehensive .gitignore for certificate files to prevent exposure
5. **Critical Incremental Deployment Failures**: Implemented comprehensive improvements to deployment process for zero-downtime operations
6. **Certificate Mounting Failures**: Fixed script to properly copy domain-specific certificates to proxy/certs/ directory

This architecture ensures complete project isolation, eliminates single points of failure, provides production-grade security, and enables seamless scalability while maintaining ease of deployment and management. The incremental deployment system now supports enterprise-grade operations with zero-downtime project additions to existing ecosystems. 