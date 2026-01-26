import queries as q

# IDEA: Specify a "folder path" and we batch download from it
TEST_BUCKET = '356070494385-us-east-1-logs'
TEST_KEY = 's3/356070494385/356070494385-us-east-1-logs/2025-03-05-19-14-19-F1818A2D8BF53EF8'
OUTPUT_PATH = "./out/example.txt"

# Get a sorted list of files to download
def get_file_list():
    pass

def download_files():
    q.download_file(TEST_BUCKET, TEST_KEY, OUTPUT_PATH)

def main():
    download_files()

if __name__=="__main__":
    main()