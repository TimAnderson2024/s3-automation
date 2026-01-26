import boto3
from datetime import datetime, date

s3 = boto3.client('s3')

# Helper method for serializing json objects
def json_default(obj):
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError(f"Type not serializable: {type(obj)}")

def query_bucket_contents(bucket: str, prefix: str):
    paginator = s3.get_paginator("list_objects_v2")
    results = []
    for page in paginator.paginate( 
        Bucket=bucket,
        Prefix=prefix,
    ):
        print("new page...")
        results.extend(page.get("Contents", []))
    
    results.sort(key=lambda o: o["LastModified"], reverse=True)

    return results

def download_file(bucket: str, key: str, filename: str):
    s3.download_file(bucket, key, filename)