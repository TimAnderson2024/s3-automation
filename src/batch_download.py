import boto3
import queries as q

# IDEA: Specify a "folder path" and we batch download from it
TEST_BUCKET = '356070494385-us-east-1-logs'
TEST_KEY = 's3/356070494385/356070494385-us-east-1-logs/2026-01-26-00'
OUTPUT_PATH = "./out/example.txt"

# Get a sorted list of files to download
def get_file_list(bucket, prefix, timestamp):
    results = q.query_bucket_contents(bucket, prefix)
    for obj in results:
        print(obj["Key"], obj["LastModified"])

def download_files():
    q.download_file(TEST_BUCKET, TEST_KEY, OUTPUT_PATH)

def batch_download():
    file_list = get_file_list(TEST_BUCKET, TEST_KEY, "")

def main():
    batch_download()

if __name__=="__main__":
    main()