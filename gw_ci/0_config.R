p0_targets <- list(
  ##### file parameters #####
  tar_target(
    p0_s3_prod_URL,
    "https://dfi09q69oy2jm.cloudfront.net/visualizations/"
  ),
  tar_target(
    p0_remote_parquet_file_template,
    "current_conditions/groundwater/stage/gw_categorizations_%s.parquet"
  ),
  tar_target(
    p0_parquet_file_dir,
    "1_fetch/out"
  ),
  tar_target(
    p0_local_parquet_file_template,
    paste(p0_parquet_file_dir, basename(p0_remote_parquet_file_template), sep = "/")
  ),
  tar_target(
    p0_remote_image_file_template,
    "current_conditions/groundwater/images/gw-%s.png"
  ),
  tar_target(
    p0_image_file_dir,
    "3_visualize/out/gw"
  ),
  tar_target(
    p0_local_image_file_template,
    paste(p0_image_file_dir, basename(p0_remote_image_file_template), sep = "/")
  ),
  ##### date parameters #####
  tar_target(
    p0_yesterday_date,
    Sys.Date() - 1,
    # ensure target is reran and not skipped for CI
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    p0_intervals,
    # will need to updated once we have 1, 3, 6, and 12 months of data from todays date
    # c(lubridate::dmonths(1), lubridate::dmonths(3), lubridate::dmonths(6),
    #   lubridate::years(1))
    c(3, 5, 7)
  ),
  tar_target(
    p0_interval_start_dates,
    p0_yesterday_date - p0_intervals
  ),
  ##### spatial parameters #####
  tar_target(
    p0_conus_proj,
    "ESRI:102004"
    ),
  # OCONUS states/territories
  tar_target(
    p0_oconus_states,
    c("Alaska","Hawaii","Puerto Rico","United States Virgin Islands","Commonwealth of the Northern Mariana Islands", "Guam", "American Samoa")
  ),
  tar_target(
    p0_oconus_states_abbr,
    c("AK","HI","PR","VI","MP", "GU","AS")
  ),
  ##### visual parameters #####
  tar_target(
    p0_viz_gw_pal,
    c(
      "Extremely above" = "#313694",
      "Much above" = "#4575b4",
      "Above normal" = "#74acd1",
      "Normal" = "grey20",
      "Below normal" = "#be812b",
      "Much below" = "#8a5109",
      "Extremely below" = "#532f05")
  ),
  tar_target(
    # Create a tibble to define fig width and height, conus outline colors,
    # background color, font name, and font size
    p0_viz_config_df,
    tibble(
      width = 1600,
      height = 1200,
      leg_width = 300,
      leg_height = 300,
      units = "px",
      fps = 10,
      dpi = 300,
      bg_col = "white",
      ggfx_col = "grey60",
      conus_states_col = "grey90",
      na_sites_col = "grey70",
      states_simplify = 0.9
    )
  ),
  tar_target(
    p0_gw_binned_scales,
    tibble(
      max_vector_height = 50000,
      mid_vector_height = 40000,
      min_vector_height = 30000,
      max_vector_width = 28000,
      max_factor = 1.2,
      mid_factor = 0.6,
      min_factor = 0.5,
      mid_vector_width = max_vector_width * mid_factor,
      min_vector_width = max_vector_width * min_factor,
      normal_width = max_vector_width * min_factor,
      max_peak_width = max_factor,
      mid_peak_width = max_factor * mid_factor,
      min_peak_width = max_factor * min_factor,
      leg_scale_mult_factor = 3.5,
      leg_xlim = 80000,
      leg_ylim = 70000
    )
  )
)
