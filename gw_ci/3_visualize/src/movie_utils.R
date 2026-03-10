#' Build groundwater mp4 for a given interval
#'
#' Filters static desktop CONUS images to those within a given date interval
#' and encodes them into an mp4 mobie.
#'
#' @param interval_start_date Start date for the animation interval.
#' @param gw_png_config Data frame containing PNG metadata.
#' @param viz_cfg Visualization configuration (contains fps).
#' @param out_dir Directory where MP4 should be saved.
#'
#' @return Character string path to saved MP4.
build_gw_mp4 <- function(interval_start_date,
                         gw_png_config,
                         viz_cfg,
                         out_dir) {
  
  filtered_df <- gw_png_config |>
    dplyr::filter(
      local_image_type == "local_desktop_static_CONUS_image_file",
      date >= interval_start_date
    ) |>
    dplyr::arrange(date)
  
  frames <- filtered_df$local_image_file
  
  interval_str <- format(interval_start_date, "%Y-%m-%d")
  
  out_path <- file.path(
    out_dir,
    sprintf("gw-movie-desktop-CONUS-%s.mp4", interval_str)
  )
  
  message(sprintf(
    "Building mp4 for interval starting %s with %s frames",
    interval_str,
    length(frames)
  ))
  
  av::av_encode_video(
    input = frames,
    output = out_path,
    framerate = viz_cfg$fps,
    vfilter = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
  )
  
  return(out_path)
}