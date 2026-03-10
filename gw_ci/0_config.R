p0_targets <- list(
  ##### file parameters #####
  tar_target(
    p0_metadata_path,
    "1_fetch/in/gw_file_metadata.csv"
    ),
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
    p0_remote_image_file_template,
    "current_conditions/groundwater/images/gw-%s-%s-%s.png"
  ),
  tar_target(
    p0_local_image_file_dir,
    "3_visualize/out/gw"
  ),
  tar_target(
    p0_local_image_type_prefix,
    "local_"
  ),
  tar_target(
    p0_logo_path,
    "3_visualize/in/usgs_logo_black.png"
  ),
  # Note: this will updated - Hayley will share
  tar_target(
    p0_desktop_leg_path,
    "3_visualize/in/mock-legend.png"
  ),
  ##### date parameters #####
  tar_target(
    p0_yesterday_date,
    # # fix date for now, while building out pipeline
    as.Date("2026/03/05"),
    # Sys.Date() - 1,
    # as_date("2026-03-29") %m-% months(1)
    # to catch 2/29
    # ensure target is reran and not skipped for CI
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    p0_intervals,
    # will need to updated once we have 1, 3, 6, and 12 months of data from todays date
    # c(lubridate::dmonths(1), lubridate::dmonths(3), lubridate::dmonths(6),
    #   lubridate::years(1))
    c(3, 5, 9)
  ),
  tar_target(
    p0_interval_start_dates,
    p0_yesterday_date - p0_intervals
  ),
  ##### spatial parameters #####
  tar_target(
    p0_area_info_df,
    tibble(
      name = c('CONUS', 'AK', 'HI', 'PR_VI', 'GU_MP', 'AS'),
      full_name = 
        c('CONUS', 'Alaska', 'Hawaii', 'Puerto Rico and the U.S. Virgin Islands', 
          'Guam and the Northern Mariana Islands', 'American Samoa'),
      state_list = c(
        list('conus' = state.abb[! state.abb %in% c('AK', 'HI')]), 'AK', 'HI', 
        list(c('PR', 'VI')), list(c('GU','MP')), 'AS'
      ),
      proj = c("EPSG:5070", "EPSG:3338", 'ESRI:102007', "EPSG:2866", "EPSG:8693", 
               "EPSG:2195"),
      proj_name = c('Albers Equal Area','Alaska Albers Equal Area',
                    'Hawaii_Albers_Equal_Area_Conic','Puerto Rico and Virgin Is.',
                    'UTM zone 55N','UTM zone 2S'),
      proj_datum = c('NAD83','NAD83','NAD83','NAD83(HARN)','NAD83(MA11)',
                     'NAD83(HARN)'),
      proj_units = c('meter','meter','meter','meter','meter','meter'),
      simplification_keep_high_simp = c(0.02, 0.011, 0.13, 0.03, 0.15, 0.03),
      simplification_keep_low_simp = c(0.1, 0.015, 0.15, 0.1, 0.2, 0.1)
    )
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
      mobile_width = 1600,
      mobile_height = 1600,
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
