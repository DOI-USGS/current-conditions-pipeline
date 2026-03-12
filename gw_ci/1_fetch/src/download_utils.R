#' Downloads a file (e.g., parquet or png) using a metadata row and
#' saves it locally using filename template.
#'
#' @param filename filename for file to download
#' @param url_prefix prefix to add to filename to construct download URL
#' @param outfile filepath for downloaded file
#'
#' @return Character string path to the downloaded file.
download_gw_file <- function(filename,
                             url_prefix,
                             outfile) {
  
  remote_url <- paste0(url_prefix, filename)
  
  message(sprintf(
    "Downloading %s and saving to %s",
    remote_url,
    outfile
  ))

  download.file(remote_url, outfile, mode = "wb")
  
  return(outfile)
}