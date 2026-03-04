#' Downloads a file (e.g., parquet or png) using a metadata row and
#' saves it locally using filename template.
#'
#' @param metadata_row A one row tibble containing `date` and a url column.
#' @param url_col Name of the column containing the remote url
#' @param output_template Filename template containing `%s` for the date.
#'
#' @return Character string path to the downloaded file.
download_gw_file <- function(metadata_row,
                             url_col,
                             output_template) {
  
  remote_url <- metadata_row[[url_col]]
  
  out <- sprintf(
    output_template,
    metadata_row[["date"]]
  )
  
  message(sprintf(
    "Downloading %s and saving to %s",
    remote_url,
    out
  ))
  
  download.file(remote_url, out, mode = "wb")
  
  return(out)
}