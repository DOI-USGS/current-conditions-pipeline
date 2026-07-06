#' Build groundwater mp4 for a given interval
#'
#' Filters static desktop CONUS images to those within a given date interval
#' and encodes them into an mp4 mobie.
#'
#' @param interval_start_date Start date for the MP4 interval.
#' @param interval_end_date End date for the MP4 interval.
#' @param interval_name Names of intervals (i.e. `last-month`, `last-3-months`..)
#' @param gw_png_config Data frame containing PNG metadata.
#' @param viz_cfg Visualization configuration (contains fps, movie_fps, bg_col).
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
  
  message(sprintf(
    "Building mp4 for %s with %s frames",
    interval_name,
    length(frames)
  ))
  
  # Duplicate each frame to reach movie_fps (e.g., 8 fps * 3 = 24 fps)
  frames_expanded <- rep(frames, each = viz_cfg$movie_fps / viz_cfg$fps)
  
  # Pad to 16:9 only (no fps resampling needed since input is already at movie_fps)
  vfilter <- sprintf(
    "pad=iw:iw*9/16:(ow-iw)/2:(oh-ih)/2:color=%s",
    viz_cfg$bg_col
  )
  
  av::av_encode_video(
    input = frames_expanded,
    output = output_template,
    framerate = viz_cfg$movie_fps,
    vfilter = vfilter
  )
  
  return(output_template)
}