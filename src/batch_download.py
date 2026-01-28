import json
import os
import queries as q
from dotenv import load_dotenv


# IDEA: Specify a "folder path" and we batch download from it
TEST_BUCKET = 'vpc-flow-logs-us-east-1-356070494385'
TEST_KEY = 'AWSLogs/356070494385/vpcflowlogs/us-east-1/2024/10/'
TEST_REGEX = r"a^"

OUTPUT_PATH = "./out"

LAST_WEEK = "s3/356070494385/356070494385-us-east-1-logs/"

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
    
    # Log the output to a txt file
    with open(f"{OUTPUT_PATH}/example.txt", 'w') as f:
        json.dump(most_recent_files, f, indent=2, default=str)

    print(f"Found {len(most_recent_files)} recent files from {target_date}")
    return most_recent_files

def download_file_list(bucket: str, file_list: list, output_path: str):
    confirm_download = input(f"Are you sure you want to download {len(file_list)} files to {output_path}? Enter YES to confirm:")
    
    if confirm_download != "YES" and confirm_download != "yes":
        print("Cancelling download...")
        return 

    for i, file in enumerate(file_list):
        key = file.get("Key", "")
        if not key:
            continue

        og_filepath = os.path.basename(key)
        destination_filepath = os.path.join(output_path, og_filepath)
        q.download_file(bucket, key, destination_filepath)

def batch_download():
    file_list = get_all_recent_files(TEST_BUCKET, TEST_KEY, TEST_REGEX)
    download_file_list(TEST_BUCKET, file_list, OUTPUT_PATH)

def main():
    load_dotenv()
    batch_download()

if __name__=="__main__":
    main()