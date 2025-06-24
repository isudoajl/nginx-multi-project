#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCS_DIR="${PROJECT_ROOT}/docs"
LOG_FILE="${SCRIPT_DIR}/logs/validate-docs.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"

# Function: Log messages
function log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function: Display test header
function display_header() {
  echo -e "\n${YELLOW}=======================================${NC}"
  echo -e "${YELLOW}   Validating Project Documentation    ${NC}"
  echo -e "${YELLOW}=======================================${NC}\n"
}

# Function: Check if file exists
function check_file_exists() {
  local file="$1"
  local description="$2"
  
  if [ -f "$file" ]; then
    log "${GREEN}✓ $description exists${NC}"
    return 0
  else
    log "${RED}✗ $description does not exist${NC}"
    return 1
  fi
}

# Function: Check if directory exists
function check_dir_exists() {
  local dir="$1"
  local description="$2"
  
  if [ -d "$dir" ]; then
    log "${GREEN}✓ $description exists${NC}"
    return 0
  else
    log "${RED}✗ $description does not exist${NC}"
    return 1
  fi
}

# Function: Check file content
function check_file_content() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  
  if grep -q "$pattern" "$file"; then
    log "${GREEN}✓ $description contains required content${NC}"
    return 0
  else
    log "${RED}✗ $description is missing required content: $pattern${NC}"
    return 1
  fi
}

# Function: Check for broken links
function check_broken_links() {
  local file="$1"
  local base_dir=$(dirname "$file")
  local errors=0
  
  # Extract markdown links
  local links=$(grep -o '\[.*\](\([^)]*\))' "$file" | sed 's/.*(\(.*\))/\1/')
  
  if [ -z "$links" ]; then
    log "${YELLOW}! No links found in $file${NC}"
    return 0
  fi
  
  log "Checking links in $file..."
  
  while IFS= read -r link; do
    # Skip external links and anchors
    if [[ "$link" == http* ]] || [[ "$link" == "#"* ]]; then
      continue
    fi
    
    # Handle relative paths
    local target_path="$base_dir/$link"
    target_path=$(realpath --relative-to="$PROJECT_ROOT" "$target_path" 2>/dev/null)
    
    if [ ! -f "$PROJECT_ROOT/$target_path" ]; then
      log "${RED}✗ Broken link: $link${NC}"
      errors=$((errors + 1))
    fi
  done <<< "$links"
  
  if [ $errors -eq 0 ]; then
    log "${GREEN}✓ All links in $file are valid${NC}"
    return 0
  else
    log "${RED}✗ Found $errors broken links in $file${NC}"
    return 1
  fi
}

# Function: Validate documentation files
function validate_docs() {
  local errors=0
  
  # Check if docs directory exists
  check_dir_exists "$DOCS_DIR" "Documentation directory" || errors=$((errors + 1))
  
  # Check required documentation files
  check_file_exists "$DOCS_DIR/README.md" "Documentation index" || errors=$((errors + 1))
  check_file_exists "$DOCS_DIR/project-container-guide.md" "Project container user guide" || errors=$((errors + 1))
  check_file_exists "$DOCS_DIR/project-container-architecture.md" "Project container architecture" || errors=$((errors + 1))
  check_file_exists "$DOCS_DIR/script-api-reference.md" "Script API reference" || errors=$((errors + 1))
  check_file_exists "$DOCS_DIR/troubleshooting-guide.md" "Troubleshooting guide" || errors=$((errors + 1))
  
  # Check content of documentation files
  if [ -f "$DOCS_DIR/project-container-guide.md" ]; then
    check_file_content "$DOCS_DIR/project-container-guide.md" "# Project Container User Guide" "Project container user guide" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/project-container-guide.md" "## Getting Started" "Project container user guide" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/project-container-guide.md" "## Creating a New Project" "Project container user guide" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/project-container-guide.md" "## Development Environment" "Project container user guide" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/project-container-guide.md" "## Local Host Configuration" "Project container user guide" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/project-container-guide.md" "## Certificate Generation" "Project container user guide" || errors=$((errors + 1))
  fi
  
  if [ -f "$DOCS_DIR/project-container-architecture.md" ]; then
    check_file_content "$DOCS_DIR/project-container-architecture.md" "# Project Container Architecture" "Project container architecture" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/project-container-architecture.md" "## Architecture Components" "Project container architecture" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/project-container-architecture.md" "## Technical Specifications" "Project container architecture" || errors=$((errors + 1))
  fi
  
  if [ -f "$DOCS_DIR/script-api-reference.md" ]; then
    check_file_content "$DOCS_DIR/script-api-reference.md" "# Script API Reference" "Script API reference" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/script-api-reference.md" "## create-project-modular.sh" "Script API reference" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/script-api-reference.md" "## update-hosts.sh" "Script API reference" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/script-api-reference.md" "## dev-environment.sh" "Script API reference" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/script-api-reference.md" "## generate-certs.sh" "Script API reference" || errors=$((errors + 1))
  fi
  
  if [ -f "$DOCS_DIR/troubleshooting-guide.md" ]; then
    check_file_content "$DOCS_DIR/troubleshooting-guide.md" "# Project Container Troubleshooting Guide" "Troubleshooting guide" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/troubleshooting-guide.md" "## Environment Setup Issues" "Troubleshooting guide" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/troubleshooting-guide.md" "## Certificate Issues" "Troubleshooting guide" || errors=$((errors + 1))
    check_file_content "$DOCS_DIR/troubleshooting-guide.md" "## Local Host Configuration Issues" "Troubleshooting guide" || errors=$((errors + 1))
  fi
  
  # Check for broken links
  for doc_file in "$DOCS_DIR"/*.md; do
    if [ -f "$doc_file" ]; then
      check_broken_links "$doc_file" || errors=$((errors + 1))
    fi
  done
  
  return $errors
}

# Main script execution
display_header
validate_docs
result=$?

if [ $result -eq 0 ]; then
  log "${GREEN}All documentation validation tests passed!${NC}"
  exit 0
else
  log "${RED}Documentation validation failed with $result errors!${NC}"
  exit 1
fi 