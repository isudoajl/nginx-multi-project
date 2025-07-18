# Script API Reference

### Project Creation Scripts

#### create-project-modular.sh

The original monolithic script for creating new project containers with all necessary configurations.

```
Usage: ./scripts/create-project-modular.sh [OPTIONS]

Create a new project container with all necessary configuration files.

Options:
  --name, -n NAME          Project name (required, alphanumeric with hyphens)
  --domain, -d DOMAIN      Domain name (required, valid FQDN format)
  --frontend, -f DIR       Path to static files (optional, default: ./projects/{project_name}/html)
  --frontend-mount, -m DIR Path to mount as frontend in container (optional, default: ./html)
  --cert, -c FILE          Path to SSL certificate (optional)
  --key, -k FILE           Path to SSL private key (optional)
  --env, -e ENV            Environment type: DEV or PRO (optional, default: DEV)
  --help, -h               Display this help message

Examples:
  ./scripts/create-project-modular.sh --name my-project --domain example.com
  ./scripts/create-project-modular.sh -n my-project -d example.com -e DEV
  ./scripts/create-project-modular.sh -n my-project -d example.com -e PRO
```

#### create-project-modular.sh

The refactored modular version of the project creation script. This script provides the same functionality as `create-project-modular.sh` but with a modular architecture for better maintainability.

> **Note:** The current implementation has module path discrepancy. The script looks for modules in `scripts/modules/` but they are actually located in `scripts/create-project/modules/`. Additionally, some referenced modules (`deployment.sh` and `verification.sh`) are missing from the implementation.

```
Usage: ./scripts/create-project-modular.sh [OPTIONS]

Create a new project container with all necessary configuration files.

Options:
  --name, -n NAME          Project name (required, alphanumeric with hyphens)
  --domain, -d DOMAIN      Domain name (required, valid FQDN format)
  --frontend, -f DIR       Path to static files (optional, default: ./projects/{project_name}/html)
  --frontend-mount, -m DIR Path to mount as frontend in container (optional, default: ./html)
  --cert, -c FILE          Path to SSL certificate (optional)
  --key, -k FILE           Path to SSL private key (optional)
  --env, -e ENV            Environment type: DEV or PRO (optional, default: DEV)
  --help, -h               Display this help message

Examples:
  ./scripts/create-project-modular.sh --name my-project --domain example.com
  ./scripts/create-project-modular.sh -n my-project -d example.com -e DEV
  ./scripts/create-project-modular.sh -n my-project -d example.com -e PRO
```

### Modular Script Architecture

The modular script is organized into separate components:

- **create-project-modular.sh**: Main script that coordinates all modules
- **modules/common.sh**: Common functions and variables shared across modules
- **modules/args.sh**: Command-line argument parsing and validation
- **modules/environment.sh**: Environment validation and configuration
- **modules/proxy.sh**: Proxy management and configuration
- **modules/proxy_utils.sh**: Utility functions for proxy-related operations
- **modules/project_structure.sh**: Project directory structure setup
- **modules/project_files.sh**: Project file generation

**Missing Modules (Referenced but not implemented):**
- **modules/deployment.sh**: Project deployment functionality
- **modules/verification.sh**: Deployment verification functionality

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