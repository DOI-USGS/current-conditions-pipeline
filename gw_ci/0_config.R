p0_targets <- list(
  ##### file parameters #####
  tar_target(
    p0_metadata_path,
    "1_fetch/in/gw_file_metadata.csv"
  ),
  tar_target(
    p0_date_json_path,
    "4_update/out/gw_dates.json"
  ),
  tar_target(
    p0_s3_prod_URL,
    "https://dfi09q69oy2jm.cloudfront.net/visualizations/"
  ),
  tar_target(
    p0_parquet_coverage_path,
    "current_conditions/groundwater/metadata/gw_coverage.parquet"
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
    p0_remote_video_file_template,
    "current_conditions/groundwater/videos/gw-%s-%s-%s.png"
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
    p0_locator_map_template,
    "locator_map_%s.png"
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
    # ensure target is reran and not skipped for CI
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    p0_intervals,
    # will need to updated once we have 1, 3, 6, and 12 months of data from todays date
    # c(lubridate::dmonths(1), lubridate::dmonths(3), lubridate::dmonths(6),
    #   lubridate::years(1))
    c(
      "last-month" = weeks(1),
      "last-3-months" = weeks(2),
      "last-6-months" = months(1),
      "last-year" = months(2)
    )
  ),
  tar_target(
    p0_interval_names,
    names(p0_intervals)
  ),
  tar_target(
    p0_interval_start_dates,
    p0_yesterday_date %m-% p0_intervals
  ),
  tar_target(
    p0_interval_dates,
    seq.Date(p0_interval_start_dates, p0_yesterday_date, by = 1),
    pattern = map(p0_interval_start_dates),
    iteration = "list"
  ),
  ##### spatial parameters #####
  tar_target(
    p0_desktop_area_name,
    "CONUS_OCONUS"
  ),
  tar_target(
    p0_area_info_df,
    tibble(
      name = c('CONUS', 'AK', 'HI', 'PR_VI', 'GU_MP', 'AS'),
      full_name = 
        c('Conterminous United States', 'Alaska', 'Hawaii', 'Puerto Rico & U.S. Virgin Islands', 
          list(c('Guam', 'Northern \nMariana Islands')), 'American Samoa'),
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
      simplification_keep_low_simp = c(0.1, 0.015, 0.15, 0.1, 0.2, 0.1),
      scale_factor = c(1, 0.5, 2, 2, 2, 2),
      placement_params = c(
        list(c("x" = 0.30, "y" = 0.01, "width" = 0.69, "height" = 0.98)),
        list(c("x" = 0.005, "y" = 0.63, "width" = 0.29, "height" = 0.38)),
        list(c("x" = 0.11, "y" = 0.30, "width" = 0.185, "height" = 0.34)),
        list(c("x" = 0.11, "y" = 0.12, "width" = 0.185, "height" = 0.17)),
        list(c("x" = 0.005, "y" = 0, "width" = 0.1, "height" = 0.63)),
        list(c("x" = 0.11, "y" = 0, "width" = 0.185, "height" = 0.12))
      )
    )
  ),
  # State-level area info, one row per lower 48 state
  # mirrors p0_area_info_df but scoped to individual states
  # all use CONUS projection EPSG:5070 for now
  tar_target(
    p0_states_area_info_df,
    tibble(
      name = state.abb[!state.abb %in% c("AK", "HI")],
      state_list = as.list(state.abb[!state.abb %in% c("AK", "HI")]),
      full_name = state.name[!state.abb %in% c("AK", "HI")],
      proj = "EPSG:5070",
      simplification_keep_high_simp = 0.02,
      scale_factor = 1
    )
  ),
  ##### visual parameters #####
  tar_target(
    p0_viz_gw_pal,
    c(
    "Extremely above" =  "#003375",
    "Much above" = "#2362b3",
    "Above normal" =   "#489dd5",
    "Normal" = "#333333",
    "Below normal" = "#c18b2f",
    "Much below" = "#8c5503",
    "Extremely below" = "#4d2b00")
    ),
  tar_target(
    # Create a tibble to define fig width and height, conus outline colors,
    # background color, font name, and font size
    p0_viz_config_df,
    tibble(
      width = 4800,
      height = 2400,
      mobile_width = 1600,
      mobile_height = 1600,
      leg_width = 300,
      leg_height = 300,
      units = "px",
      fps = 10,
      dpi = 300,
      bg_col = "white",
      ggfx_col = "#999999",
      ggfx_sigma = 25,
      inner_states_col = "#949494",
      inner_states_stroke = 0.25,
      outer_states_col = "#949494",
      outer_states_stroke = 0.1,
      na_sites_col = "grey70",
      na_sites_size_desktop = 0.9,
      na_sites_size_mobile = 0.6,
      na_sites_stroke = 0.25,
      normal_sites_stroke = 0.25,
      primary_font_color = "#000000",
      plot_font = "Source Sans 3",
      scale_font = paste(plot_font, "Light Italic"),
      scale_font_size = 16,
      scale_font_color = "#6E6E6E",
      annotation_font = paste(plot_font, "Italic"),
      annotation_font_size = 16,
      annotation_font_color = "#4F4F4F",
      scale_line_color = '#949494',
      scale_lwd = 0.25,
      date_font = paste(plot_font, "Bold"),
      date_font_size = 24,
      date_font_color = "#000000",
      locator_map_focal_area_color = "gray20",
      locator_map_width = 600,
      locator_map_height = 600
    )
  ),
  tar_target(
    p0_gw_binned_scales,
    tibble(
      max_vector_height = 50000,
      mid_vector_height = 40000,
      min_vector_height = 30000,
      max_vector_width = 28000,
      max_factor = 2, # Adjust based on plot width to match max_vector_width,
      max_factor_mobile = 1,
      mid_factor = 0.75,
      min_factor = 0.5,
      mid_vector_width = max_vector_width * mid_factor,
      min_vector_width = max_vector_width * min_factor,
      normal_width = max_vector_width * min_factor,
      max_peak_width = max_factor,
      mid_peak_width = max_factor * mid_factor,
      min_peak_width = max_factor * min_factor,
      leg_scale_mult_factor = 2.4,
      leg_xlim = 80000,
      leg_ylim = 70000
    )
  )
)
