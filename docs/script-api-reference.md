# Script API Reference

### Project Creation Scripts

#### create-project-modular.sh

The main script for creating project containers with support for both frontend-only and full-stack deployments.

```
Usage: ./scripts/create-project-modular.sh [OPTIONS]

Create a new project container with all necessary configuration files.
Supports both frontend-only and full-stack deployments with backend services.

Options:
  --name, -n NAME          Project name (required, alphanumeric with hyphens)
  --domain, -d DOMAIN      Domain name (required, valid FQDN format)
  --frontend, -f DIR       Path to static files (optional, default: ./projects/{project_name}/html)
  --frontend-mount, -m DIR Path to mount as frontend in container (optional, default: ./html)
  --cert, -c FILE          Path to SSL certificate (optional)
  --key, -k FILE           Path to SSL private key (optional)
  --env, -e ENV            Environment type: DEV or PRO (optional, default: DEV)
  
  Full-Stack/Monorepo Options:
  --monorepo DIR           Path to monorepo root (enables full-stack deployment)
  --frontend-dir DIR       Subdirectory containing frontend code (default: frontend)
  --backend-dir DIR        Subdirectory containing backend code (enables backend services)
  --backend-port PORT      Backend service port (default: 3000)
  --backend-build CMD      Custom backend build command (optional)
  
  --help, -h               Display this help message

Examples:
  # Frontend-only deployment
  ./scripts/create-project-modular.sh --name my-project --domain example.com
  
  # Development environment
  ./scripts/create-project-modular.sh -n my-project -d example.com -e DEV
  
  # Production environment
  ./scripts/create-project-modular.sh -n my-project -d example.com -e PRO
  
  # Full-stack monorepo deployment
  ./scripts/create-project-modular.sh \
    --name my-app \
    --domain my-app.com \
    --monorepo /path/to/monorepo \
    --frontend-dir frontend \
    --backend-dir backend \
    --backend-port 3000 \
    --env PRO
    
  # Custom backend build command
  ./scripts/create-project-modular.sh \
    --name rust-app \
    --domain rust-app.com \
    --monorepo /opt/rust-project \
    --backend-dir server \
    --backend-build "cargo build --release" \
    --env PRO
```

## Full-Stack Deployment Features

The script now supports comprehensive full-stack deployment capabilities including:

### Backend Framework Support
- **Rust**: Cargo-based build with `cargo build --release`
- **Node.js**: npm/yarn builds with `npm run build` or custom commands
- **Go**: Go module builds with `go build`
- **Python**: Python package builds and runtime setup

### Multi-Service Container Architecture
- **Frontend**: Static files served by nginx
- **Backend**: Application server running on configurable port
- **API Routing**: nginx proxy configuration for `/api/*` → backend
- **Health Checks**: Both frontend and backend health monitoring
- **Process Management**: Startup script coordinating both services

### Modular Script Architecture

The script is organized into separate modules for maintainability:

- **create-project-modular.sh**: Main script that coordinates all modules
- **modules/common.sh**: Common functions and variables shared across modules
- **modules/args.sh**: Command-line argument parsing and backend framework detection
- **modules/environment.sh**: Environment validation and configuration
- **modules/proxy.sh**: Proxy management and configuration
- **modules/proxy_utils.sh**: Utility functions for proxy-related operations
- **modules/project_structure.sh**: Project directory structure setup
- **modules/project_files.sh**: Multi-stage Dockerfile and configuration generation
- **modules/deployment.sh**: Full-stack project deployment and container management
- **modules/verification.sh**: Network connectivity and health check verification

### Other Scripts

#### update-hosts.sh

```
Usage: ./scripts/update-hosts.sh [OPTIONS]

Update local hosts file with domain entries for development.

Options:
  --domain, -d DOMAIN      Domain name to add/remove
  --action, -a ACTION      Action to perform: add or remove
  --help, -h               Display this help message

Examples:
  ./scripts/update-hosts.sh --domain example.com --action add
  ./scripts/update-hosts.sh -d example.com -a remove
```

#### dev-environment.sh

```
Usage: ./scripts/dev-environment.sh [OPTIONS]

Set up development environment for a project.

Options:
  --project, -p PROJECT    Project name
  --action, -a ACTION      Action to perform: setup or teardown
  --port, -P PORT          Port to use (optional, default: 8080)
  --help, -h               Display this help message

Examples:
  ./scripts/dev-environment.sh --project my-project --action setup --port 8080
  ./scripts/dev-environment.sh -p my-project -a teardown
```

#### manage-proxy.sh

```
Usage: ./scripts/manage-proxy.sh [OPTIONS]

Manage the nginx proxy container.

Options:
  --action, -a ACTION      Action to perform: start, stop, restart, status
  --help, -h               Display this help message

Examples:
  ./scripts/manage-proxy.sh --action start
  ./scripts/manage-proxy.sh -a restart
```

#### generate-certs.sh

```
Usage: ./scripts/generate-certs.sh [OPTIONS]

Generate SSL certificates for development or production.

Options:
  --domain, -d DOMAIN      Domain name (required)
  --env, -e ENV            Environment type: DEV or PRO (optional, default: DEV)
  --output, -o DIR         Output directory (optional)
  --help, -h               Display this help message

Examples:
  ./scripts/generate-certs.sh --domain example.com
  ./scripts/generate-certs.sh -d example.com -e PRO -o /path/to/certs
``` 