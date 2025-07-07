#!/bin/bash

# Test script for Nix monorepo guide documentation

# Set up test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_LOG="${SCRIPT_DIR}/test-nix-monorepo-guide.log"
DOC_FILE="${PROJECT_ROOT}/docs/nix-monorepo-guide.md"

# Initialize log file
echo "Starting test: $(date)" > "$TEST_LOG"

# Test function
function test_log() {
  echo "[$(date +%H:%M:%S)] $1" | tee -a "$TEST_LOG"
}

function run_test() {
  local test_name="$1"
  local test_cmd="$2"
  local expected_output="$3"
  local invert_match="${4:-false}"
  
  test_log "Running test: ${test_name}"
  
  # Run the test command
  local output
  output=$(eval "$test_cmd" 2>&1)
  local exit_code=$?
  
  # Check if output contains expected string
  if [ "$invert_match" = "false" ] && echo "$output" | grep -q "$expected_output"; then
    test_log "✅ Test passed: ${test_name}"
    return 0
  elif [ "$invert_match" = "true" ] && ! echo "$output" | grep -q "$expected_output"; then
    test_log "✅ Test passed: ${test_name}"
    return 0
  else
    test_log "❌ Test failed: ${test_name}"
    test_log "Expected ${invert_match:+NOT }to find: $expected_output"
    test_log "Actual output: $output"
    return 1
  fi
}

# Test 1: Check if documentation file exists
if [ -f "$DOC_FILE" ]; then
  test_log "✅ Documentation file exists: $DOC_FILE"
else
  test_log "❌ Documentation file not found: $DOC_FILE"
  exit 1
fi

# Test 2: Check if documentation contains required sections
test_log "Checking for required sections..."
required_sections=(
  "Overview"
  "Prerequisites"
  "Monorepo Requirements"
  "Deployment Command"
  "Parameter Reference"
  "Build Process"
  "Example Project Types"
  "Container Structure"
  "Troubleshooting"
)

for section in "${required_sections[@]}"; do
  if grep -q "^## $section" "$DOC_FILE"; then
    test_log "✅ Found required section: $section"
  else
    test_log "❌ Missing required section: $section"
    exit 1
  fi
done

# Test 3: Check if documentation contains all required parameters
test_log "Checking for required parameters..."
required_params=(
  "use-nix-build"
  "mono-repo"
  "frontend-path"
  "frontend-build-dir"
  "frontend-build-cmd"
  "backend-path"
  "backend-build-cmd"
  "backend-start-cmd"
)

for param in "${required_params[@]}"; do
  if grep -q -- "$param" "$DOC_FILE"; then
    test_log "✅ Found required parameter: --$param"
  else
    test_log "❌ Missing required parameter: --$param"
    exit 1
  fi
done

# Test 4: Check if documentation contains example commands
test_log "Checking for example commands..."
if grep -q "./scripts/create-project-modular.sh" "$DOC_FILE"; then
  test_log "✅ Found example commands"
else
  test_log "❌ Missing example commands"
  exit 1
fi

# Test 5: Check if documentation is referenced in DOCS.md
DOCS_INDEX="${PROJECT_ROOT}/docs/DOCS.md"
if grep -q "nix-monorepo-guide.md" "$DOCS_INDEX"; then
  test_log "✅ Documentation is referenced in DOCS.md"
else
  test_log "❌ Documentation is not referenced in DOCS.md"
  exit 1
fi

# Test 6: Check if implementation status is updated
IMPL_STATUS="${PROJECT_ROOT}/IMPLEMENTATION_STATUS_REFACTOR.md"
if grep -q "Partially Implemented.*2025-07-13" "$IMPL_STATUS" && grep -q "nix-monorepo-guide.md" "$IMPL_STATUS"; then
  test_log "✅ Implementation status is updated"
else
  test_log "❌ Implementation status is not updated"
  test_log "Expected to find 'Partially Implemented.*2025-07-13' and 'nix-monorepo-guide.md' in IMPLEMENTATION_STATUS_REFACTOR.md"
  exit 1
fi

# All tests passed
test_log "✅ All tests passed for Nix monorepo guide documentation"
echo "Test completed successfully at $(date)" >> "$TEST_LOG"
exit 0 