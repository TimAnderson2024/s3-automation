# S3 Batch download

Python script that utilizes boto3 to batch download S3 objects

## Setup
Download pip requirements: 
python -m venv venv
source venv/scripts/activate
pip install -r requirements.txt

Fill in config.json:
- bucket: The taget bucket
- key_prefix: Only download objects whose key matches this key_prefix
- exclude_regex: Exclude all objects that match to this exclude_regex
- output_path: Relative path to download files to

Add config to .env file: env_config_path="<your-config.json>"
OR 
Add config in terminal: export env_config_path="<your-config.json>"

## Usage
aws sso login --profile <profile>
src/batch_download.py

## Run all accounts from env_configs directory
Use the helper script to process every JSON file in env_configs/:

bash run_batch_download_all.sh

### Prerequisites
1. Virtual environment activated: source venv/Scripts/activate
2. Dependencies installed: pip install -r requirements.txt
3. AWS credentials configured: aws sso login --profile <profile>
4. Configuration files in env_configs/ directory with required fields

### Options
- --check-only: Run validation checks without executing downloads
- --fail-fast: Stop on first failed configuration
- --help: Show usage help

### Environment Variables
- CHECK_ONLY=1: Enable check-only mode
- FAIL_FAST=1: Enable fail-fast mode (stop on first failure)
- VENV_PATH=/path/to/venv: Override virtual environment path (default: ./venv)

### Examples
bash run_batch_download_all.sh                    # Run all configs
bash run_batch_download_all.sh --check-only       # Validate only
FAIL_FAST=1 bash run_batch_download_all.sh        # Stop on first failure

### Expected config fields per JSON file in env_configs/
Each .json file in env_configs/ must contain:
- bucket: S3 bucket to read from (required)
- exclude_regex: Regex pattern to exclude keys (required)
- account: AWS CLI profile name or account identifier (optional, for labeling)
- output_path: Download destination folder (optional, defaults to out/<filename>)
- region: AWS region (optional, uses profile default)

### Exit Codes
- 0: All configurations processed successfully
- 1: One or more configurations failed, or validation errors occurred