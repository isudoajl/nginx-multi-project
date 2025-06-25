#!/bin/bash

# Module for SSL certificate validation
# Ensures required certificates are available before project deployment

# Function: Validate SSL certificates
function validate_ssl_certificates() {
  log "🔒 Validating SSL certificates..."
  
  local certs_dir="${CERTS_DIR}"
  
  # Check if certs directory exists
  if [[ ! -d "$certs_dir" ]]; then
    handle_error "Certificates directory not found: $certs_dir
Please create the certificates directory first."
  fi
  
  # Check for any .pem files in the certs directory
  local pem_files=($(find "$certs_dir" -maxdepth 1 -name "*.pem" -type f 2>/dev/null))
  
  if [[ ${#pem_files[@]} -eq 0 ]]; then
    echo ""
    echo "❌ No SSL certificate files (.pem) found in $certs_dir"
    echo ""
    echo "🔒 Certificate Setup Required:"
    echo "   Please populate the certs/ directory with SSL certificate files before proceeding."
    echo ""
    echo "   You can either:"
    echo "   1. Copy existing SSL certificates (.pem files)"
    echo "   2. Generate new certificates using: ./scripts/generate-certs.sh"
    echo "   3. Use self-signed certificates for development/testing"
    echo ""
    echo "   Example commands:"
    echo "   # Generate new certificates:"
    echo "   ./scripts/generate-certs.sh"
    echo ""
    echo "   # Or copy existing certificates:"
    echo "   cp /path/to/your/certificate.pem certs/"
    echo "   cp /path/to/your/private-key.pem certs/"
    echo ""
    handle_error "SSL certificates (.pem files) are required for project deployment"
  fi
  
  log "📋 Found ${#pem_files[@]} SSL certificate file(s):"
  for pem_file in "${pem_files[@]}"; do
    local filename=$(basename "$pem_file")
    
    # Validate file is readable and not empty
    if [[ ! -s "$pem_file" ]]; then
      log "⚠️  Warning: Certificate file is empty or unreadable: $filename"
      continue
    fi
    
    # Check certificate format (basic validation)
    if grep -q "BEGIN CERTIFICATE" "$pem_file"; then
      log "  ✅ $filename (Certificate)"
      
      # Additional certificate information if openssl is available
      if command -v openssl >/dev/null 2>&1; then
        local cert_subject=$(openssl x509 -in "$pem_file" -noout -subject 2>/dev/null | sed 's/subject=//' || echo "Unable to read subject")
        local cert_expires=$(openssl x509 -in "$pem_file" -noout -enddate 2>/dev/null | sed 's/notAfter=//' || echo "Unable to read expiration")
        
        log "     Subject: $cert_subject"
        log "     Expires: $cert_expires"
        
        # Check if certificate is expired or expiring soon
        if openssl x509 -in "$pem_file" -checkend 2592000 >/dev/null 2>&1; then
          log "     Status: Valid (not expiring within 30 days)"
        else
          log "     ⚠️  Status: Expires within 30 days or already expired"
        fi
      fi
    elif grep -q "BEGIN.*PRIVATE KEY" "$pem_file"; then
      log "  🔑 $filename (Private Key)"
    elif grep -q "BEGIN.*KEY" "$pem_file"; then
      log "  🔑 $filename (Key)"
    else
      log "  ❓ $filename (Unknown format - may not be a valid PEM file)"
    fi
  done
  
  log "✅ SSL certificate validation completed successfully"
  return 0
}

# Function: Validate certificate permissions
function validate_certificate_permissions() {
  log "🔐 Validating certificate permissions..."
  
  local certs_dir="${CERTS_DIR}"
  local pem_files=($(find "$certs_dir" -maxdepth 1 -name "*.pem" -type f 2>/dev/null))
  
  for pem_file in "${pem_files[@]}"; do
    local filename=$(basename "$pem_file")
    local file_perms=$(stat -c "%a" "$pem_file" 2>/dev/null || stat -f "%Lp" "$pem_file" 2>/dev/null || echo "unknown")
    
    # Check if this is a private key file
    if grep -q "BEGIN.*PRIVATE KEY" "$pem_file" || grep -q "BEGIN.*KEY" "$pem_file"; then
      # Private key files should have 600 permissions
      if [[ "$file_perms" == "600" ]]; then
        log "✅ Private key permissions are secure: $filename ($file_perms)"
      else
        log "⚠️  Warning: Private key permissions should be 600 for security: $filename ($file_perms)"
        log "   Setting secure permissions: chmod 600 $pem_file"
        chmod 600 "$pem_file" || log "⚠️  Failed to set secure permissions on $filename"
      fi
    else
      # Certificate files can have 644 or 600 permissions
      if [[ "$file_perms" == "644" ]] || [[ "$file_perms" == "600" ]]; then
        log "✅ Certificate permissions are secure: $filename ($file_perms)"
      else
        log "⚠️  Warning: Certificate permissions may be too permissive: $filename ($file_perms)"
        log "   Consider setting permissions to 644: chmod 644 $pem_file"
      fi
    fi
  done
}

# Function: Complete certificate validation
function validate_certificates() {
  log "Starting SSL certificate validation process..."
  
  # Validate certificate existence and format
  validate_ssl_certificates
  
  # Validate certificate permissions
  validate_certificate_permissions
  
  log "🎉 Certificate validation completed successfully!"
  return 0
} 