import json
import os
import queries as q
from dotenv import load_dotenv

# Get a sorted list of files to download
def get_all_recent_files(bucket: str, prefix: str, regex: str):
    # Send the query
    results = q.query_bucket_contents(bucket, prefix, regex)

    # Filter on the most recent results date
    target_date = results[0].get("LastModified").date()
    most_recent_files = [
        result for result in results 
        if result.get("LastModified").date() == target_date
    ]

    print(f"Found {len(most_recent_files)} recent files from {target_date}")
    return most_recent_files

def download_file_list(bucket: str, file_list: list, output_path: str):
    confirm_download = input(f"Are you sure you want to download {len(file_list)} files to {output_path}? Enter YES to confirm:")
    
    if confirm_download != "YES" and confirm_download != "yes":
        print("Cancelling download...")
        return 

    for file in file_list:
        key = file.get("Key", "")
        if not key:
            continue

        og_filepath = os.path.basename(key)
        destination_filepath = os.path.join(output_path, og_filepath)
        q.download_file(bucket, key, destination_filepath)

def batch_download(env_config: dict):
    file_list = get_all_recent_files(env_config["bucket"], env_config["key_prefix"], env_config["exclude_regex"])
    
    # Log the output to a txt file
    with open(f"{env_config['output_path']}/raw.txt", 'w') as f:
        json.dump(file_list, f, indent=2, default=str)
    
    download_file_list(env_config["bucket"], file_list, env_config["output_path"])

def main():
    load_dotenv()
    config_path = os.getenv("env_config_path")
    with open(config_path, "r") as f:
        env_config = json.load(f)
    
    batch_download(env_config)

if __name__=="__main__":
    main()