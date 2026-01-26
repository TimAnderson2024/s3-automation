import boto3
from datetime import datetime, date

s3 = boto3.client('s3')

# Helper method for serializing json objects
def json_default(obj):
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError(f"Type not serializable: {type(obj)}")

def query_bucket_contents(bucket: str):
    return s3.list_objects_v2(bucket)

def download_file(bucket: str, key: str, filename: str):
    s3.download_file(bucket, key, filename)