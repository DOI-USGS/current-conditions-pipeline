import os
import urllib.request

def download_file_urllib(url, folder_location, filename=None):
    """Downloads a file from a url

    Parameters
    ----------
    url: string
        url of the file
    folder_location: string
        folder path of the downloaded file
    filename: string
        filename
   
    Returns
    -------
        Saved file in specified folder

    """
    os.makedirs(folder_location, exist_ok=True)
    if filename is None:
        filename = url.split('/')[-1]
    file_path = os.path.join(folder_location, filename)
    urllib.request.urlretrieve(url, file_path)

def download_s3(s3_url_prefix, s3_file, folder):
    """Downloads an s3 file and prints out the url"""
    print ("downloading... " + s3_url_prefix + s3_file)
    download_file_urllib(s3_url_prefix + s3_file, folder)

if __name__ == "__main__":
    s3_url_prefix = snakemake.params["s3_url_prefix"]
    folder = snakemake.params["folder"]
    s3_file = snakemake.output["s3_file"]

    download_s3(s3_url_prefix, s3_file, folder)
