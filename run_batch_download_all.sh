#!/usr/bin/env bash

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CONFIGS_DIR="${SCRIPT_DIR}/env_configs"
OUT_DIR="${SCRIPT_DIR}/out"
VENV_PATH="${VENV_PATH:-${SCRIPT_DIR}/venv}"
PYTHON_SCRIPT="${SCRIPT_DIR}/src/batch_download.py"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
CHECK_ONLY="${CHECK_ONLY:-0}"
FAIL_FAST="${FAIL_FAST:-0}"

# Tracking
TOTAL_CONFIGS=0
SUCCEEDED=0
FAILED=0
FAILED_CONFIGS=()

# Helper: print error and exit
die() {
    printf "${RED}ERROR: %s${NC}\n" "$1" >&2
    exit 1
}

# Helper: print warning
warn() {
    printf "${YELLOW}WARNING: %s${NC}\n" "$1" >&2
}

# Helper: print info
info() {
    printf "${GREEN}✓ %s${NC}\n" "$1"
}

# Helper: print step
step() {
    printf "\n${YELLOW}=== %s ===${NC}\n" "$1"
}

# Check required directories exist
check_directory_structure() {
    step "Checking directory structure"
    
    [[ -d "${ENV_CONFIGS_DIR}" ]] || die "env_configs directory not found at ${ENV_CONFIGS_DIR}"
    info "env_configs directory exists"
    
    [[ -d "${OUT_DIR}" ]] || die "out directory not found at ${OUT_DIR}"
    info "out directory exists"
    
    [[ -f "${PYTHON_SCRIPT}" ]] || die "batch_download.py not found at ${PYTHON_SCRIPT}"
    info "batch_download.py exists"
    
    [[ -f "${REQUIREMENTS_FILE}" ]] || die "requirements.txt not found at ${REQUIREMENTS_FILE}"
    info "requirements.txt exists"
}

# Verify config files exist
check_config_files() {
    step "Checking env_configs for JSON files"
    
    local config_count=0
    if [[ -d "${ENV_CONFIGS_DIR}" ]]; then
        config_count=$(find "${ENV_CONFIGS_DIR}" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l)
    fi
    
    if [[ ${config_count} -eq 0 ]]; then
        die "No .json files found in ${ENV_CONFIGS_DIR}"
    fi
    
    info "Found ${config_count} JSON configuration file(s)"
}

# Check virtual environment is active
check_venv_active() {
    step "Verifying virtual environment"
    
    if [[ -z "${VIRTUAL_ENV:-}" ]]; then
        die "Virtual environment not active. Activate with: source ${VENV_PATH}/Scripts/activate"
    fi
    
    info "Virtual environment is active: ${VIRTUAL_ENV}"
}

# Verify critical Python packages are installed
check_dependencies() {
    step "Verifying Python dependencies"
    
    local required_packages=("boto3" "dotenv")
    local missing=()
    
    for pkg in "${required_packages[@]}"; do
        if ! python -c "import ${pkg}" 2>/dev/null; then
            missing+=("${pkg}")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required packages: ${missing[*]}. Install with: pip install -r ${REQUIREMENTS_FILE}"
    fi
    
    info "All required packages are installed"
}

# Validate JSON file syntax and required fields
validate_json_config() {
    local config_file="$1"
    
    # Check JSON syntax and extract required fields
    local validation_result
    validation_result=$(python -c "
import json
import os
try:
    # Use raw string and current working directory
    fpath = os.path.join(os.getcwd(), '$config_file')
    with open(fpath, 'r') as f:
        data = json.load(f)
    
    bucket = data.get('bucket', '')
    exclude_regex = data.get('exclude_regex', '')
    
    if not bucket:
        print('MISSING_BUCKET')
    elif not exclude_regex:
        print('MISSING_EXCLUDE_REGEX')
    else:
        print('VALID')
except json.JSONDecodeError:
    print('INVALID_JSON')
except Exception as e:
    print(f'ERROR: {str(e)}')
" 2>&1)
    
    case "${validation_result}" in
        VALID)
            return 0
            ;;
        MISSING_BUCKET)
            warn "Missing required field 'bucket' in ${config_file}"
            return 1
            ;;
        MISSING_EXCLUDE_REGEX)
            warn "Missing required field 'exclude_regex' in ${config_file}"
            return 1
            ;;
        INVALID_JSON)
            warn "Invalid JSON syntax in ${config_file}"
            return 1
            ;;
        *)
            warn "Validation error in ${config_file}: ${validation_result}"
            return 1
            ;;
    esac
}

# Validate all JSON configs
validate_all_configs() {
    step "Validating JSON configuration files"
    
    local invalid_count=0
    local -a config_files
    
    # Read all JSON files into array
    while IFS= read -r -d '' config_file; do
        config_files+=("$config_file")
    done < <(find "${ENV_CONFIGS_DIR}" -maxdepth 1 -name "*.json" -type f -print0 2>/dev/null)
    
    for config_file in "${config_files[@]}"; do
        local basename=$(basename "${config_file}")
        local rel_path="env_configs/${basename}"
        
        if validate_json_config "${rel_path}"; then
            info "Valid: ${basename}"
        else
            warn "Invalid or incomplete: ${basename}"
            ((invalid_count++))
        fi
    done
    
    if [[ ${invalid_count} -gt 0 ]]; then
        die "${invalid_count} configuration file(s) failed validation"
    fi
}

# Execute batch download for a single config
run_batch_download() {
    local config_file="$1"
    local config_name=$(basename "${config_file}" .json)
    
    printf "\n${YELLOW}--- Processing: ${config_name} ---${NC}\n"
    
    # Export config path for Python script
    export env_config_path="${config_file}"
    
    # Run the Python script
    if python "${PYTHON_SCRIPT}"; then
        info "Successfully processed ${config_name}"
        ((SUCCEEDED++))
        return 0
    else
        warn "Failed to process ${config_name}"
        FAILED_CONFIGS+=("${config_name}")
        ((FAILED++))
        return 1
    fi
}

# Main execution loop
execute_batch_downloads() {
    step "Executing batch downloads"
    
    local -a config_files
    
    # Read all JSON files into array
    while IFS= read -r -d '' config_file; do
        config_files+=("$config_file")
    done < <(find "${ENV_CONFIGS_DIR}" -maxdepth 1 -name "*.json" -type f -print0 2>/dev/null)
    
    for config_file in "${config_files[@]}"; do
        local basename=$(basename "${config_file}" .json)
        local rel_path="env_configs/$(basename "${config_file}")"
        
        ((TOTAL_CONFIGS++))
        
        if ! run_batch_download "${rel_path}"; then
            if [[ "${FAIL_FAST}" == "1" ]]; then
                die "Stopping due to FAIL_FAST flag"
            fi
        fi
    done
}

# Print summary
print_summary() {
    step "Execution Summary"
    
    printf "Total configs processed: ${TOTAL_CONFIGS}\n"
    printf "${GREEN}Succeeded: ${SUCCEEDED}${NC}\n"
    
    if [[ ${FAILED} -gt 0 ]]; then
        printf "${RED}Failed: ${FAILED}${NC}\n"
        printf "Failed configs:\n"
        for config in "${FAILED_CONFIGS[@]}"; do
            printf "  - ${config}\n"
        done
    else
        printf "Failed: ${FAILED}\n"
    fi
}

# Parse command-line flags
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check-only)
                CHECK_ONLY=1
                shift
                ;;
            --fail-fast)
                FAIL_FAST=1
                shift
                ;;
            --help)
                print_help
                exit 0
                ;;
            *)
                die "Unknown argument: $1"
                ;;
        esac
    done
}

# Print usage information
print_help() {
    cat <<EOF
${GREEN}Usage:${NC} bash run_batch_download_all.sh [OPTIONS]

${GREEN}Options:${NC}
  --check-only     Run validation checks without executing downloads
  --fail-fast      Stop on first failed configuration
  --help           Show this help message

${GREEN}Environment Variables:${NC}
  CHECK_ONLY       Set to 1 to enable check-only mode (default: 0)
  FAIL_FAST        Set to 1 to enable fail-fast mode (default: 0)
  VENV_PATH        Path to virtual environment (default: ./venv)

${GREEN}Example:${NC}
  bash run_batch_download_all.sh
  bash run_batch_download_all.sh --check-only
  FAIL_FAST=1 bash run_batch_download_all.sh

${GREEN}Prerequisites:${NC}
  1. Virtual environment activated: source venv/Scripts/activate
  2. Dependencies installed: pip install -r requirements.txt
  3. AWS credentials configured: aws sso login --profile <profile>
  4. Configuration files in env_configs/ with required fields:
     - bucket (required)
     - exclude_regex (required)
     - account (optional, for labeling)
     - output_path (optional, defaults to out/<account>)
EOF
}

# Main entry point
main() {
    parse_args "$@"
    
    printf "${GREEN}S3 Batch Download Wrapper${NC}\n"
    printf "Script directory: ${SCRIPT_DIR}\n\n"
    
    # Run validation checks
    check_directory_structure
    check_config_files
    check_venv_active
    check_dependencies
    validate_all_configs
    
    # If check-only mode, exit after validation
    if [[ "${CHECK_ONLY}" == "1" ]]; then
        info "Check-only mode: all validations passed"
        exit 0
    fi
    
    # Execute downloads
    execute_batch_downloads
    
    # Print summary
    print_summary
    
    # Exit with appropriate code
    if [[ ${FAILED} -gt 0 ]]; then
        exit 1
    fi
    
    exit 0
}

main "$@"
