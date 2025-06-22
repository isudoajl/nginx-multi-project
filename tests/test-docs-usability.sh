#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCS_DIR="${PROJECT_ROOT}/docs"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function: Check environment
function check_environment() {
  # Check if we're in a Nix environment
  if [ -z "$IN_NIX_SHELL" ]; then
    echo -e "${RED}Error: Please enter Nix environment with 'nix develop' first${NC}"
    exit 1
  fi
}

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Test the usability of proxy documentation."
  echo ""
  echo "Options:"
  echo "  -d, --docs-dir DIR    Documentation directory (default: ../docs)"
  echo "  -v, --verbose         Show detailed test results"
  echo "  -h, --help            Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --verbose"
  echo "  $0 --docs-dir /path/to/docs"
}

# Function: Parse arguments
function parse_arguments() {
  # Default values
  DOCS_DIR="${PROJECT_ROOT}/docs"
  VERBOSE=false
  
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -d|--docs-dir)
        DOCS_DIR="$2"
        shift 2
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      -h|--help)
        display_help
        exit 0
        ;;
      *)
        echo "Unknown parameter: $1"
        display_help
        exit 1
        ;;
    esac
  done
}

# Function: Check if docs directory exists
function check_docs_directory() {
  if [ ! -d "$DOCS_DIR" ]; then
    echo -e "${RED}Error: Documentation directory not found: $DOCS_DIR${NC}"
    echo "Please run scripts/validate-proxy-docs.sh first to generate documentation."
    exit 1
  fi
}

# Function: Test technical documentation usability
function test_technical_documentation() {
  echo "Testing technical documentation usability..."
  
  local failed_tests=0
  
  # Test proxy architecture document
  if [ -f "${DOCS_DIR}/technical/proxy-architecture.md" ]; then
    # Check for required sections
    if ! grep -q "## Overview" "${DOCS_DIR}/technical/proxy-architecture.md" || \
       ! grep -q "## Components" "${DOCS_DIR}/technical/proxy-architecture.md" || \
       ! grep -q "## Directory Structure" "${DOCS_DIR}/technical/proxy-architecture.md"; then
      echo -e "${RED}✗ proxy-architecture.md is missing required sections${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ proxy-architecture.md has all required sections${NC}"
      fi
    fi
    
    # Check for code examples
    if ! grep -q '```' "${DOCS_DIR}/technical/proxy-architecture.md"; then
      echo -e "${RED}✗ proxy-architecture.md is missing code examples${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ proxy-architecture.md has code examples${NC}"
      fi
    fi
  fi
  
  # Test configuration options document
  if [ -f "${DOCS_DIR}/technical/configuration-options.md" ]; then
    # Check for required sections
    if ! grep -q "## Main Configuration" "${DOCS_DIR}/technical/configuration-options.md" || \
       ! grep -q "## SSL/TLS Configuration" "${DOCS_DIR}/technical/configuration-options.md" || \
       ! grep -q "## Security Headers" "${DOCS_DIR}/technical/configuration-options.md"; then
      echo -e "${RED}✗ configuration-options.md is missing required sections${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ configuration-options.md has all required sections${NC}"
      fi
    fi
  fi
  
  # Test networking setup document
  if [ -f "${DOCS_DIR}/technical/networking-setup.md" ]; then
    # Check for required sections
    if ! grep -q "## Network Isolation" "${DOCS_DIR}/technical/networking-setup.md" || \
       ! grep -q "## Docker Compose Configuration" "${DOCS_DIR}/technical/networking-setup.md"; then
      echo -e "${RED}✗ networking-setup.md is missing required sections${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ networking-setup.md has all required sections${NC}"
      fi
    fi
    
    # Check for code examples
    if ! grep -q '```yaml' "${DOCS_DIR}/technical/networking-setup.md"; then
      echo -e "${RED}✗ networking-setup.md is missing YAML examples${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ networking-setup.md has YAML examples${NC}"
      fi
    fi
  fi
  
  return $failed_tests
}

# Function: Test operational documentation usability
function test_operational_documentation() {
  echo "Testing operational documentation usability..."
  
  local failed_tests=0
  
  # Test proxy management document
  if [ -f "${DOCS_DIR}/operational/proxy-management.md" ]; then
    # Check for required sections
    if ! grep -q "## Starting the Proxy" "${DOCS_DIR}/operational/proxy-management.md" || \
       ! grep -q "## Stopping the Proxy" "${DOCS_DIR}/operational/proxy-management.md" || \
       ! grep -q "## Reloading Configuration" "${DOCS_DIR}/operational/proxy-management.md"; then
      echo -e "${RED}✗ proxy-management.md is missing required sections${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ proxy-management.md has all required sections${NC}"
      fi
    fi
    
    # Check for command examples
    if ! grep -q '```bash' "${DOCS_DIR}/operational/proxy-management.md"; then
      echo -e "${RED}✗ proxy-management.md is missing command examples${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ proxy-management.md has command examples${NC}"
      fi
    fi
  fi
  
  # Test troubleshooting document
  if [ -f "${DOCS_DIR}/operational/troubleshooting.md" ]; then
    # Check for required sections
    if ! grep -q "## Common Issues" "${DOCS_DIR}/operational/troubleshooting.md" || \
       ! grep -q "## Diagnostic Commands" "${DOCS_DIR}/operational/troubleshooting.md"; then
      echo -e "${RED}✗ troubleshooting.md is missing required sections${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ troubleshooting.md has all required sections${NC}"
      fi
    fi
  fi
  
  # Test maintenance document
  if [ -f "${DOCS_DIR}/operational/maintenance.md" ]; then
    # Check for required sections
    if ! grep -q "## Routine Maintenance" "${DOCS_DIR}/operational/maintenance.md" || \
       ! grep -q "## Performance Optimization" "${DOCS_DIR}/operational/maintenance.md" || \
       ! grep -q "## Security Updates" "${DOCS_DIR}/operational/maintenance.md"; then
      echo -e "${RED}✗ maintenance.md is missing required sections${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ maintenance.md has all required sections${NC}"
      fi
    fi
  fi
  
  return $failed_tests
}

# Function: Test integration documentation usability
function test_integration_documentation() {
  echo "Testing integration documentation usability..."
  
  local failed_tests=0
  
  # Test project integration document
  if [ -f "${DOCS_DIR}/integration/project-integration.md" ]; then
    # Check for required sections
    if ! grep -q "## Project Requirements" "${DOCS_DIR}/integration/project-integration.md" || \
       ! grep -q "## Integration Steps" "${DOCS_DIR}/integration/project-integration.md" || \
       ! grep -q "## Example Integration" "${DOCS_DIR}/integration/project-integration.md"; then
      echo -e "${RED}✗ project-integration.md is missing required sections${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ project-integration.md has all required sections${NC}"
      fi
    fi
    
    # Check for code examples
    if ! grep -q '```bash' "${DOCS_DIR}/integration/project-integration.md"; then
      echo -e "${RED}✗ project-integration.md is missing bash examples${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ project-integration.md has bash examples${NC}"
      fi
    fi
  fi
  
  # Test proxy management API document
  if [ -f "${DOCS_DIR}/integration/proxy-management-api.md" ]; then
    # Check for required sections
    if ! grep -q "## Script API" "${DOCS_DIR}/integration/proxy-management-api.md" || \
       ! grep -q "## Docker API" "${DOCS_DIR}/integration/proxy-management-api.md"; then
      echo -e "${RED}✗ proxy-management-api.md is missing required sections${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ proxy-management-api.md has all required sections${NC}"
      fi
    fi
    
    # Check for command examples
    if ! grep -q '```bash' "${DOCS_DIR}/integration/proxy-management-api.md"; then
      echo -e "${RED}✗ proxy-management-api.md is missing command examples${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ proxy-management-api.md has command examples${NC}"
      fi
    fi
  fi
  
  # Test integration examples document
  if [ -f "${DOCS_DIR}/integration/integration-examples.md" ]; then
    # Check for required sections
    if ! grep -q "## Example 1:" "${DOCS_DIR}/integration/integration-examples.md" || \
       ! grep -q "## Example 2:" "${DOCS_DIR}/integration/integration-examples.md"; then
      echo -e "${RED}✗ integration-examples.md is missing example sections${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ integration-examples.md has example sections${NC}"
      fi
    fi
    
    # Check for code examples
    if ! grep -q '```bash' "${DOCS_DIR}/integration/integration-examples.md"; then
      echo -e "${RED}✗ integration-examples.md is missing bash examples${NC}"
      failed_tests=$((failed_tests+1))
    else
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ integration-examples.md has bash examples${NC}"
      fi
    fi
  fi
  
  return $failed_tests
}

# Function: Test documentation links
function test_documentation_links() {
  echo "Testing documentation links..."
  
  local failed_tests=0
  local broken_links=0
  
  # Find all markdown files
  local md_files=$(find "$DOCS_DIR" -name "*.md")
  
  for file in $md_files; do
    # Extract relative links from markdown files
    local links=$(grep -o '\[.*\](.*\.md)' "$file" | sed -E 's/\[.*\]\((.*)\)/\1/')
    
    for link in $links; do
      # Convert relative path to absolute
      local target_file
      if [[ "$link" == /* ]]; then
        # Absolute path from docs root
        target_file="${DOCS_DIR}${link}"
      else
        # Relative path from current file
        target_file="$(dirname "$file")/$link"
      fi
      
      # Check if the linked file exists
      if [ ! -f "$target_file" ]; then
        echo -e "${RED}✗ Broken link in $(basename "$file"): $link${NC}"
        broken_links=$((broken_links+1))
      elif [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ Valid link in $(basename "$file"): $link${NC}"
      fi
    done
  done
  
  if [ $broken_links -gt 0 ]; then
    echo -e "${RED}Found $broken_links broken links in documentation${NC}"
    failed_tests=1
  elif [ "$VERBOSE" = true ]; then
    echo -e "${GREEN}All documentation links are valid${NC}"
  fi
  
  return $failed_tests
}

# Function: Test documentation readability
function test_documentation_readability() {
  echo "Testing documentation readability..."
  
  local failed_tests=0
  local readability_issues=0
  
  # Find all markdown files
  local md_files=$(find "$DOCS_DIR" -name "*.md")
  
  for file in $md_files; do
    # Check for headings structure
    if ! grep -q "^# " "$file"; then
      echo -e "${RED}✗ $(basename "$file") is missing a top-level heading${NC}"
      readability_issues=$((readability_issues+1))
    fi
    
    # Check for overly long paragraphs (more than 20 lines without a break)
    if grep -A 20 "^[A-Za-z]" "$file" | grep -q "^$"; then
      if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}⚠ $(basename "$file") has very long paragraphs${NC}"
      fi
    fi
    
    # Check for code blocks with language specification
    if grep -q "^```$" "$file"; then
      echo -e "${YELLOW}⚠ $(basename "$file") has code blocks without language specification${NC}"
      readability_issues=$((readability_issues+1))
    fi
  done
  
  if [ $readability_issues -gt 0 ]; then
    echo -e "${RED}Found $readability_issues readability issues in documentation${NC}"
    failed_tests=1
  elif [ "$VERBOSE" = true ]; then
    echo -e "${GREEN}Documentation has good readability${NC}"
  fi
  
  return $failed_tests
}

# Function: Generate summary report
function generate_summary_report() {
  local tech_failed=$1
  local op_failed=$2
  local int_failed=$3
  local links_failed=$4
  local readability_failed=$5
  
  local total_failed=$((tech_failed + op_failed + int_failed + links_failed + readability_failed))
  local total_tests=5
  local pass_percentage=$(( (total_tests - (total_failed > 0 ? 1 : 0)) * 100 / total_tests ))
  
  echo ""
  echo "Documentation Usability Test Summary:"
  echo "------------------------------------"
  echo "Technical Documentation: $([ $tech_failed -eq 0 ] && echo "${GREEN}PASS${NC}" || echo "${RED}FAIL${NC}")"
  echo "Operational Documentation: $([ $op_failed -eq 0 ] && echo "${GREEN}PASS${NC}" || echo "${RED}FAIL${NC}")"
  echo "Integration Documentation: $([ $int_failed -eq 0 ] && echo "${GREEN}PASS${NC}" || echo "${RED}FAIL${NC}")"
  echo "Documentation Links: $([ $links_failed -eq 0 ] && echo "${GREEN}PASS${NC}" || echo "${RED}FAIL${NC}")"
  echo "Documentation Readability: $([ $readability_failed -eq 0 ] && echo "${GREEN}PASS${NC}" || echo "${RED}FAIL${NC}")"
  echo ""
  echo "Overall Result: $pass_percentage% PASS"
  
  if [ $total_failed -eq 0 ]; then
    echo -e "${GREEN}All documentation usability tests passed!${NC}"
    return 0
  else
    echo -e "${RED}Some documentation usability tests failed.${NC}"
    return 1
  fi
}

# Main script execution
check_environment
parse_arguments "$@"
check_docs_directory

tech_failed=0
op_failed=0
int_failed=0
links_failed=0
readability_failed=0

test_technical_documentation
tech_failed=$?

test_operational_documentation
op_failed=$?

test_integration_documentation
int_failed=$?

test_documentation_links
links_failed=$?

test_documentation_readability
readability_failed=$?

generate_summary_report $tech_failed $op_failed $int_failed $links_failed $readability_failed
exit_code=$?

exit $exit_code