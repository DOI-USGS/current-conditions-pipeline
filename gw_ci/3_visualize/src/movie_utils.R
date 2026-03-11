#' Build groundwater mp4 for a given interval
#'
#' Filters static desktop CONUS images to those within a given date interval
#' and encodes them into an mp4 mobie.
#'
#' @param interval_start_date Start date for the MP4 interval.
#' @param interval_end_date End date for the MP4 interval.
#' @param interval_name Names of intervals (i.e. `last-month`, `last-3-months`..)
#' @param gw_png_config Data frame containing PNG metadata.
#' @param viz_cfg Visualization configuration (contains fps).
#' @param img_type_name Local image type name to filter by.
#' @param output_template Directory where MP4 should be saved.
#'
#' @return Character string path to saved MP4.
build_gw_mp4 <- function(interval_start_date,
                         interval_end_date, 
                         interval_name,
                         gw_png_config,
                         viz_cfg,
                         output_template,
                         img_type_name) {
  
  filtered_df <- gw_png_config |>
    dplyr::filter(
      local_image_type == img_type_name,
      date >= interval_start_date,
      date <= interval_end_date
    ) |>
    dplyr::arrange(date)
  
  frames <- filtered_df$local_image_file
  
  interval_str <- format(interval_start_date, "%Y-%m-%d")

  message(sprintf(
    "Building mp4 for %s with %s frames",
    interval_name,
    length(frames)
  ))
  
  
  av::av_encode_video(
    input = frames,
    output = output_template,
    framerate = viz_cfg$fps,
    vfilter = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
  )
  
  return(output_template)
}