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