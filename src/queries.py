import boto3
import re
from datetime import datetime, date

s3 = boto3.client('s3')

OUTPUT_PATH = "./out/example.txt"
import json

def query_bucket_contents(bucket: str, prefix: str, regex: str):
    paginator = s3.get_paginator("list_objects_v2")
    results = []
    
    for page in paginator.paginate( 
        Bucket=bucket,
        Prefix=prefix,
    ):
        results.extend(page.get("Contents", []))
        print(f"Fetched {len(results)} total objects")

    results.sort(key=lambda o: o["LastModified"], reverse=True)
    
    pattern = re.compile(regex, re.IGNORECASE)
    filtered_results = [ 
        result for result in results
        if not pattern.search(result.get("Key", ""))
    ]
    print(f"{len(filtered_results)} results remaining after filtering")
    
    return results

def download_file(bucket: str, key: str, filename: str):
    s3.download_file(bucket, key, filename)