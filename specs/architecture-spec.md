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

4. **Certificate Management**
   - Flexible certificate location with sensible defaults
   - Support for both development (self-signed) and production certificates
   - Centralized or distributed certificate storage options

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

Each project container will operate on its own isolated network, with the proxy container being the only component with access to all project networks. This ensures:

1. Projects cannot directly communicate with each other
2. External access is controlled exclusively through the proxy
3. Security breaches in one project cannot affect others

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

1. Project configuration generation
2. Container image building
3. Network setup
4. Container deployment
5. Proxy configuration update
6. Health verification
7. DNS updates (if applicable)

This architecture ensures complete project isolation, eliminates single points of failure, provides production-grade security, and enables seamless scalability while maintaining ease of deployment and management. 