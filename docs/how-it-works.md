# How It Works - Microservices Nginx Architecture

This document explains the technical architecture and operation of the Microservices Nginx Architecture.

## System Overview

The Microservices Nginx Architecture is designed to provide a scalable, secure, and maintainable infrastructure for hosting multiple isolated web applications using Nginx and container technology. The system consists of:

1. **Central Nginx Proxy**: A reverse proxy that handles SSL termination, domain routing, and security features
2. **Project Containers**: Isolated containers for each project with their own Nginx instances
3. **Network Isolation**: Separate networks for each project with controlled communication
4. **Automation Scripts**: Comprehensive tooling for deployment and management

## Architecture Components

### 1. Central Nginx Proxy

The central proxy container (`nginx-proxy`) serves as the entry point for all external traffic. It:

- Listens on ports 8080 (HTTP) and 8443 (HTTPS)
- Terminates SSL/TLS connections
- Routes traffic to the appropriate project container based on the domain name
- Applies security headers and rate limiting
- Blocks malicious bots and unusual HTTP methods
- Redirects HTTP to HTTPS

```
┌─────────────────────────────────────┐
│           nginx-proxy               │
│                                     │
│  ┌─────────────┐    ┌─────────────┐ │
│  │    HTTP     │    │    HTTPS    │ │
│  │  (8080)     │    │   (8443)    │ │
│  └─────────────┘    └─────────────┘ │
│            │              │         │
│            └──────────────┘         │
│                   │                 │
└───────────────────┼─────────────────┘
                    │
                    ▼
          Domain-based Routing
```

### 2. Project Containers

Each project runs in its own isolated container with:

- Its own Nginx instance listening on port 80
- Project-specific configuration
- Static file serving
- Health check endpoints
- Security hardening

```
┌─────────────────────────────────────┐
│           project-container         │
│                                     │
│  ┌─────────────┐    ┌─────────────┐ │
│  │    Nginx    │    │   Static    │ │
│  │  (Port 80)  │    │   Files     │ │
│  └─────────────┘    └─────────────┘ │
│                                     │
│  ┌─────────────┐    ┌─────────────┐ │
│  │   Health    │    │  Security   │ │
│  │   Check     │    │  Headers    │ │
│  └─────────────┘    └─────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### 3. Network Architecture

The network architecture provides isolation between projects while allowing controlled communication:

- **nginx-proxy-network**: Shared network for communication between proxy and project containers
- **project-specific networks**: Isolated networks for each project

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

### 4. SSL Certificate Management

SSL certificates are managed at multiple levels:

- **Master certificates**: Stored in the `certs/` directory at the project root
- **Domain-specific certificates**: Generated for each project and stored in `certs/<domain>/`
- **Proxy certificates**: Copied to the proxy container for SSL termination

### 5. Automation Scripts

The system includes comprehensive automation scripts for:

- Project creation and deployment
- Certificate management
- Environment configuration
- Proxy integration
- Deployment verification

## Deployment Flow

The deployment process follows these steps:

1. **Environment Setup**: Validate the environment and prepare for deployment
2. **Certificate Generation**: Generate or validate SSL certificates
3. **Proxy Setup**: Check and configure the central proxy
4. **Project Structure**: Create the project directory structure
5. **Project Files**: Generate project-specific configuration files
6. **Environment Configuration**: Configure for development or production
7. **Deployment**: Build and start the project container
8. **Verification**: Verify the deployment was successful

## Zero-Downtime Incremental Deployment

The system supports adding new projects to a running ecosystem without disrupting existing services:

1. **Proxy Detection**: Automatically detect if the proxy is running
2. **Preserve Existing Configuration**: Keep existing domain configurations intact
3. **Network Integration**: Connect new project to the proxy network
4. **Certificate Integration**: Copy domain-specific certificates to proxy
5. **Configuration Testing**: Test new configuration before applying
6. **Safe Reload**: Reload proxy configuration without disrupting existing services
7. **Rollback Capability**: Revert changes if configuration reload fails

## Environment Support

The system supports both development and production environments:

### Development Environment (DEV)

- Self-signed SSL certificates
- Local DNS resolution via hosts file
- Hot reload for development
- Detailed logging for debugging

### Production Environment (PRO)

- Production SSL certificates
- Cloudflare integration
- Enhanced security settings
- Performance optimization

## Security Features

The system includes comprehensive security features:

1. **SSL/TLS Termination**: Modern SSL configuration at proxy level
2. **Security Headers**: HSTS, CSP, X-Frame-Options, and more
3. **Network Isolation**: Projects cannot communicate directly
4. **Rate Limiting**: Prevent DDoS attacks
5. **Bad Bot Blocking**: Block malicious bots
6. **Method Filtering**: Block unusual HTTP methods

## Podman Integration

The system includes complete podman integration for rootless container operation:

1. **Rootless Operation**: Containers run without root privileges
2. **Network Management**: Custom networks for isolation
3. **Docker Compatibility**: Compatible with Docker Compose files
4. **IP-based Routing**: Use container IP addresses for reliable routing

## Flow Diagrams

### Project Creation Flow

```
┌─────────────────┐
│ Start           │
└────────┬────────┘
         │
┌────────▼────────┐
│ Parse Arguments │
└────────┬────────┘
         │
┌────────▼────────┐
│ Validate Env    │
└────────┬────────┘
         │
┌────────▼────────┐
│ Check SSL Certs │
└────────┬────────┘
         │
┌────────▼────────┐
│ Check Proxy     │◄───┐
└────────┬────────┘    │
         │             │
┌────────▼────────┐    │
│ Setup Project   │    │
└────────┬────────┘    │
         │             │
┌────────▼────────┐    │
│ Generate Files  │    │
└────────┬────────┘    │
         │             │
┌────────▼────────┐    │
│ Configure Env   │    │
└────────┬────────┘    │
         │             │
┌────────▼────────┐    │
│ Deploy Project  │    │
└────────┬────────┘    │
         │             │
┌────────▼────────┐    │
│ Verify Success  │────┘
└────────┬────────┘
         │
┌────────▼────────┐
│ Done            │
└─────────────────┘
```

### Request Flow

```
┌─────────────────┐
│ Client Request  │
└────────┬────────┘
         │
┌────────▼────────┐
│ DNS Resolution  │
└────────┬────────┘
         │
┌────────▼────────┐
│ nginx-proxy     │
│ (8080/8443)     │
└────────┬────────┘
         │
┌────────▼────────┐
│ SSL Termination │
└────────┬────────┘
         │
┌────────▼────────┐
│ Security Checks │
└────────┬────────┘
         │
┌────────▼────────┐
│ Domain Routing  │
└────────┬────────┘
         │
┌────────▼────────┐
│ Project Container│
└────────┬────────┘
         │
┌────────▼────────┐
│ Response        │
└─────────────────┘
```

## Conclusion

The Microservices Nginx Architecture provides a robust, scalable, and secure infrastructure for hosting multiple web applications. The system's modular design, comprehensive automation, and security features make it suitable for both development and production environments. 