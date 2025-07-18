# Test Monorepo Project

This is a test monorepo project designed to validate the nginx-multi-project monorepo functionality.

## Structure

```
tests/test-monorepo-project/
├── flake.nix              # Nix flake configuration
├── frontend/              # Frontend application
│   ├── package.json       # Node.js dependencies and build scripts  
│   └── src/              # Frontend source code
│       ├── index.html    # Main application page
│       └── health.html   # Health check endpoint
└── README.md             # This file
```

## Features

### 🔧 Nix Integration
- **flake.nix**: Defines the Nix build environment and packages
- **Frontend package**: Builds the frontend using npm within Nix
- **Development shell**: Provides Node.js and npm for development

### 📦 Frontend Application
- **Simple HTML/CSS/JS**: Static frontend application
- **Build process**: npm-based build that copies files to dist/
- **Health endpoint**: Provides health check functionality
- **Responsive design**: Modern CSS with gradient background

### 🧪 Testing Capabilities

This monorepo tests the following functionality:

1. **Nix Detection**: Script detects existing flake.nix
2. **Frontend Build**: npm build process integration
3. **Multi-stage Docker**: Nix + Nginx container build
4. **Container Deployment**: Project container creation
5. **Proxy Integration**: Nginx reverse proxy configuration
6. **Health Monitoring**: Health check endpoint validation

## Usage

This test monorepo is used by the integration tests to validate monorepo deployment:

```bash
# Test the monorepo deployment
./scripts/create-project-modular.sh \
  --name test-monorepo \
  --domain test-monorepo.local \
  --monorepo ./tests/test-monorepo-project \
  --frontend-dir frontend \
  --env DEV
```

## Validation

When deployed successfully, this monorepo will:

1. ✅ Build the frontend using the existing Nix configuration
2. ✅ Create a multi-stage Docker container
3. ✅ Deploy with nginx reverse proxy integration  
4. ✅ Serve the application at the configured domain
5. ✅ Provide health check endpoints
6. ✅ Demonstrate zero-downtime incremental deployment

## Expected Results

- **Main page**: Displays success status and feature validation
- **Health check**: `/health.html` returns OK status
- **SSL/HTTPS**: Properly configured with certificates
- **Domain routing**: Accessible via configured domain name
- **Container networking**: Internal communication working

This test monorepo validates that the nginx-multi-project system can successfully deploy monorepo projects with existing Nix configurations.
