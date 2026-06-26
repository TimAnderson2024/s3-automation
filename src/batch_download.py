#!/usr/bin/env python

import json
import os
import sys
import re
import boto3

from dotenv import load_dotenv

s3 = boto3.client('s3')
    

def query_bucket_contents(bucket: str):
    paginator = s3.get_paginator("list_objects_v2")
    results = []
    
    for page in paginator.paginate( 
        Bucket=bucket,
    ):
        results.extend(page.get("Contents", []))
        print(f"Fetched {len(results)} total objects")

    return results


def get_nessus_scans(bucket: str, exclude_regex: str):
    results = query_bucket_contents(bucket)

    results.sort(key=lambda o: o["LastModified"], reverse=True)
    
    # Filter on the most recent results date and regex
    target_date = results[0].get("LastModified").date()
    pattern = re.compile(exclude_regex, re.IGNORECASE)

    filtered_files = [
        result for result in results 
        if result.get("LastModified").date() == target_date and 
        not pattern.search(result.get("Key", ""))
    ]
    print(f"{len(filtered_files)} results remaining after filtering")
    
    return filtered_files


def download_file(bucket: str, key: str, filename: str):
    print(f"Downloading {filename}...")
    try:
        s3.download_file(bucket, key, filename)
        print(f"\tSuccessfully downloaded")
    except:
        print(f"\tFailed to download, skipping...")


def download_file_list(bucket: str, file_list: list, output_path: str):
    confirm_download = input(f"Are you sure you want to download {len(file_list)} files to {output_path}? Enter YES to confirm:")
    
    if confirm_download not in ("YES",  "yes", "y", "ye"):
        print("Cancelling download...")
        return 

    for file in file_list:
        key = file.get("Key", "")
        if not key:
            continue
        
        if key.endswith("/"):
            print(f"Skipping folder key: {key}")
            continue

        og_filepath = os.path.basename(key)
        if not og_filepath:
            print(f"Skipping key with empty basename: {key}")
            continue    
        destination_filepath = os.path.join(output_path, og_filepath)
        os.makedirs(os.path.dirname(destination_filepath), exist_ok=True)
        download_file(bucket, key, destination_filepath)

def batch_download(env_config: dict):
    file_list = get_nessus_scans(env_config["bucket"], env_config["exclude_regex"])
    
    download_file_list(env_config["bucket"], file_list, env_config["output_path"])

def main():
    load_dotenv()

    try: 
        config_path = os.getenv("env_config_path")
        print(config_path)
        with open(config_path, "r") as f:
            env_config = json.load(f)
    except: 
        print("Failed to load config file")
        sys.exit(0)
    
    batch_download(env_config)

if __name__=="__main__":
    main()