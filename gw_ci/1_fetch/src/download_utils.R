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
                             outfile,
                             verbose = F) {
  
  remote_url <- paste0(url_prefix, filename)
  
  if (verbose) {
    message(sprintf(
      "Downloading %s and saving to %s",
      remote_url,
      outfile
    ))
    download.file(remote_url, outfile, mode = "wb", quiet = F)
  } else {
    download.file(remote_url, outfile, mode = "wb", quiet = T)
  }
  
  return(outfile)
}

#' Download a background image from S3 if it exists there.
#'
#' Background images are static and not tracked in the metadata CSV, so existence
#' is determined by attempting the download. Returns TRUE if the file was
#' downloaded, FALSE if it was not found on S3.
#'
#' @param outfile local path the background should be downloaded to
#' @param url_prefix prefix prepended to the remote key to form the download URL
#' @param remote_template remote image path template; its directory is the S3
#'   folder for the background, with `basename(outfile)` appended
#'
#' @return Logical; TRUE if downloaded, FALSE if not present on S3.
download_gw_bkgd_if_exists <- function(outfile,
                                       url_prefix,
                                       remote_template) {

  remote_key <- file.path(dirname(remote_template), basename(outfile))

  tryCatch({
    download_gw_file(
      filename = remote_key,
      url_prefix = url_prefix,
      outfile = outfile
    )
    TRUE
  }, error = function(e) {
    message("Background not on S3, will create: ", basename(outfile))
    FALSE
  })
}