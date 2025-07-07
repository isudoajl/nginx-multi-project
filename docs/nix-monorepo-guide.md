# Nix-Based Monorepo Build Guide

## Overview

This guide explains how to deploy projects from monorepos using the Nginx Multi-Project Architecture's Nix-based build system. The system supports building both frontend and backend components from a single monorepo source, resulting in a containerized deployment with proper isolation and integration with the central proxy.

## Prerequisites

- **Nix Package Manager** with flakes support
- **Monorepo Structure** with a valid `flake.nix` in the root
- **Container Engine** (Podman or Docker)
- **Nginx Multi-Project Architecture** set up

## Monorepo Requirements

### 1. Valid Flake.nix

Your monorepo must contain a valid `flake.nix` file in the root directory. This file defines the Nix development environment that will be used for building your project.

Example `flake.nix`:

```nix
{
  description = "My monorepo project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            nodePackages.npm
            # Add other dependencies as needed
          ];
        };
      }
    );
}
```

### 2. Frontend Structure

Your frontend code should be organized in a subdirectory within the monorepo and have a build command that produces static files.

Example structure:
```
monorepo/
├── flake.nix
├── flake.lock
├── packages/
│   ├── frontend/
│   │   ├── package.json
│   │   ├── src/
│   │   └── dist/  # Build output directory
│   └── backend/
│       ├── package.json
│       └── src/
```

### 3. Backend Structure (Optional)

If you're including a backend service, it should be in a separate subdirectory with build and start commands.

## Deployment Command

To deploy a project from a monorepo using Nix-based builds:

```bash
# Enter Nix environment first
nix --extra-experimental-features "nix-command flakes" develop

# Deploy project with Nix build
./scripts/create-project-modular.sh \
  --name my-project \
  --port 8090 \
  --domain my-project.com \
  --env DEV \
  --use-nix-build \
  --mono-repo /path/to/monorepo \
  --frontend-path packages/frontend \
  --frontend-build-dir dist \
  --frontend-build-cmd "npm run build" \
  --backend-path packages/backend \
  --backend-build-cmd "npm run build" \
  --backend-start-cmd "npm start" \
  --env-vars "NODE_ENV=production,API_URL=https://api.example.com"
```

## Parameter Reference

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| `--use-nix-build` | Enable Nix-based containerized builds | Yes | `--use-nix-build` |
| `--mono-repo` | Path to monorepo on host | Yes | `--mono-repo /path/to/monorepo` |
| `--frontend-path` | Relative path to frontend within monorepo | Yes | `--frontend-path packages/frontend` |
| `--frontend-build-dir` | Frontend build output directory | Yes | `--frontend-build-dir dist` |
| `--frontend-build-cmd` | Command to build frontend | Yes | `--frontend-build-cmd "npm run build"` |
| `--backend-path` | Relative path to backend within monorepo | No | `--backend-path packages/backend` |
| `--backend-build-cmd` | Command to build backend | Required if backend-path is specified | `--backend-build-cmd "npm run build"` |
| `--backend-start-cmd` | Command to start backend | No (defaults to backend-build-cmd) | `--backend-start-cmd "npm start"` |

## Build Process

When you deploy a project with Nix-based builds, the following happens:

1. **Monorepo Copy**: The monorepo is copied to the project directory
2. **Nix Environment Detection**: The system verifies the presence of `flake.nix`
3. **Multi-Stage Build**:
   - First stage: Builds frontend and backend using the monorepo's Nix environment
   - Second stage: Creates the final image with only the built artifacts
4. **Container Configuration**:
   - For frontend-only projects: Configures nginx to serve static files
   - For full-stack projects: Sets up supervisord to manage both nginx and the backend service
5. **Proxy Integration**: Connects the container to the nginx-proxy network

## Example Project Types

### React Frontend Only

```bash
./scripts/create-project-modular.sh \
  --name react-app \
  --port 8090 \
  --domain react-app.local \
  --env DEV \
  --use-nix-build \
  --mono-repo /path/to/monorepo \
  --frontend-path packages/react-app \
  --frontend-build-dir build \
  --frontend-build-cmd "npm run build"
```

### Vue.js Frontend with Node.js Backend

```bash
./scripts/create-project-modular.sh \
  --name vue-node-app \
  --port 8091 \
  --domain vue-node-app.local \
  --env DEV \
  --use-nix-build \
  --mono-repo /path/to/monorepo \
  --frontend-path packages/vue-app \
  --frontend-build-dir dist \
  --frontend-build-cmd "npm run build" \
  --backend-path packages/node-api \
  --backend-build-cmd "npm run build" \
  --backend-start-cmd "node dist/server.js" \
  --env-vars "NODE_ENV=development,PORT=3000"
```

### Angular Frontend with Rust Backend

```bash
./scripts/create-project-modular.sh \
  --name angular-rust-app \
  --port 8092 \
  --domain angular-rust-app.local \
  --env DEV \
  --use-nix-build \
  --mono-repo /path/to/monorepo \
  --frontend-path packages/angular-app \
  --frontend-build-dir dist \
  --frontend-build-cmd "npm run build" \
  --backend-path packages/rust-api \
  --backend-build-cmd "cargo build --release" \
  --backend-start-cmd "./target/release/rust-api" \
  --env-vars "RUST_LOG=info,DATABASE_URL=postgres://user:pass@localhost/db"
```

## Container Structure

The resulting container will have the following structure:

```
/
├── usr/share/nginx/html/  # Frontend static files
├── opt/backend/           # Backend code (if specified)
├── etc/nginx/             # Nginx configuration
├── etc/supervisor/        # Supervisor configuration (if backend specified)
└── var/log/               # Log files
```

## Troubleshooting

### Common Issues

#### 1. Flake.nix Not Found

```
ERROR: flake.nix not found in monorepo root
```

**Solution**: Ensure your monorepo has a valid `flake.nix` file in the root directory.

#### 2. Build Command Failure

```
ERROR: Frontend build command failed
```

**Solution**: Verify that your build command works correctly within the Nix environment. Test it manually:

```bash
cd /path/to/monorepo
nix develop
cd packages/frontend
npm run build
```

#### 3. Backend Service Not Starting

**Solution**: Check the backend logs in the container:

```bash
podman logs my-project
# or
podman exec -it my-project cat /var/log/backend.log
```

#### 4. Network Connectivity Issues

If the backend cannot be reached from the frontend:

**Solution**: Verify that nginx is correctly configured to proxy requests to the backend service. Check the nginx configuration:

```bash
podman exec -it my-project cat /etc/nginx/nginx.conf
```

## Best Practices

1. **Optimize Build Performance**:
   - Use `.dockerignore` to exclude unnecessary files
   - Keep monorepo size manageable
   - Consider using build caching strategies

2. **Environment Variables**:
   - Use `--env-vars` to pass environment-specific configuration
   - Store sensitive information in environment variables, not in the codebase

3. **Health Checks**:
   - Implement health check endpoints in both frontend and backend
   - Use the built-in `/health/` endpoint for container health monitoring

4. **Logging**:
   - Configure proper logging for your backend service
   - Monitor logs for troubleshooting: `podman logs my-project`

## Advanced Configuration

### Custom Backend Port

The default backend port is 3000. If your backend uses a different port, update the nginx configuration:

```bash
# After deployment, edit nginx.conf
podman exec -it my-project vi /etc/nginx/nginx.conf

# Change the proxy_pass line to use your custom port
# proxy_pass http://localhost:YOUR_PORT/;
```

### Custom Supervisor Configuration

For advanced backend service management:

```bash
# After deployment, edit supervisord.conf
podman exec -it my-project vi /etc/supervisor/conf.d/supervisord.conf
```

## Conclusion

The Nix-based build system provides a powerful way to deploy projects from monorepos with both frontend and backend components. By leveraging Nix environments, you get reproducible builds and consistent deployment across different environments.

For more information, see:
- [Deployment Guide](./deployment-guide.md)
- [Project Container Architecture](./project-container-architecture.md)
- [Troubleshooting Guide](./troubleshooting-guide.md) 