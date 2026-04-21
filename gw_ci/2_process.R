tar_source("2_process/src/spatial_utils.R")
tar_source("2_process/src/process_gw_data.R")

p2_targets <- list(
  ##### spatial data #####
  # higher degree of simplification for desktop
  tar_target(
    p2_areas_sf_high_simp_list,
    munge_area_polys(
      states_sf = p1_states_sf,
      area_name = p0_area_info_df[["name"]],
      area_state_list = p0_area_info_df[["state_list"]],
      area_proj = p0_area_info_df[["proj"]],
      simplification_keep = p0_area_info_df[["simplification_keep_high_simp"]]
    ),
    pattern = map(p0_area_info_df),
    iteration = "list"
  ),
  # WGS 84 projection to use when making locator map(s)
  tar_target(
    p2_areas_sf_high_simp_wgs84_list,
    p2_areas_sf_high_simp_list |>
      purrr::map(sf::st_transform, crs = "EPSG:4326"),
    iteration = "list"
  ),
  # prep info for CONUS + OCONUS layout
  tar_target(
    p2_areas_high_simp_max_x_extent,
    unique(p2_areas_sf_high_simp_list[[which(
      p0_area_info_df[["name"]] == "CONUS"
    )]][["x_extent"]])
  ),
  tar_target(
    p2_areas_high_simp_max_y_extent,
    unique(p2_areas_sf_high_simp_list[[which(
      p0_area_info_df[["name"]] == "CONUS"
    )]][["y_extent"]])
  ),
  tar_target(
    p2_areas_high_simp_extents_df,
    get_relative_extent_information(
      area_info_df = p0_area_info_df,
      area_sf = p2_areas_sf_high_simp_list,
      max_x_extent = p2_areas_high_simp_max_x_extent,
      max_y_extent = p2_areas_high_simp_max_y_extent
    ),
    pattern = map(p0_area_info_df, p2_areas_sf_high_simp_list),
    iteration = "list"
  ),
  # lower degree of simplification for mobile
  tar_target(
    p2_areas_sf_low_simp_list,
    munge_area_polys(
      states_sf = p1_states_sf,
      area_name = p0_area_info_df[["name"]],
      area_state_list = p0_area_info_df[["state_list"]],
      area_proj = p0_area_info_df[["proj"]],
      simplification_keep = p0_area_info_df[["simplification_keep_low_simp"]]
    ),
    pattern = map(p0_area_info_df),
    iteration = "list"
  ),
  # prep info for scaling scale parameters
  tar_target(
    p2_areas_low_simp_max_x_extent,
    unique(p2_areas_sf_low_simp_list[[which(
      p0_area_info_df[["name"]] == "CONUS"
    )]][["x_extent"]])
  ),
  tar_target(
    p2_areas_low_simp_max_y_extent,
    unique(p2_areas_sf_low_simp_list[[which(
      p0_area_info_df[["name"]] == "CONUS"
    )]][["y_extent"]])
  ),
  tar_target(
    p2_areas_low_simp_extents_df,
    get_relative_extent_information(
      area_info_df = p0_area_info_df,
      area_sf = p2_areas_sf_low_simp_list,
      max_x_extent = p2_areas_low_simp_max_x_extent,
      max_y_extent = p2_areas_low_simp_max_y_extent
    ),
    pattern = map(p0_area_info_df, p2_areas_sf_low_simp_list),
    iteration = "list"
  ),
  # state lookup table
  tar_target(
    p2_state_lookup,
    tigris::states(cb = TRUE, resolution = "500k") |>
      sf::st_drop_geometry() |>
      select(
        state_name_std = NAME,
        state_abbr = STUSPS
      )
  ),
  ##### State polygon data #####
  # State polygons, branched by state row in p0_states_area_info_df
  # mirrors p2_areas_sf_high_simp_list / p2_areas_high_simp_extents_df
  tar_target(
    p2_states_sf_list,
    munge_area_polys(
      states_sf = p1_states_sf,
      area_name = p0_states_area_info_df[["name"]],
      area_state_list = p0_states_area_info_df[["state_list"]],
      area_proj = p0_states_area_info_df[["proj"]],
      simplification_keep = p0_states_area_info_df[["simplification_keep_high_simp"]]
    ),
    pattern = map(p0_states_area_info_df),
    iteration = "list"
  ),
  tar_target(
    p2_states_extents_df,
    get_relative_extent_information(
      area_info_df = p0_states_area_info_df,
      area_sf = p2_states_sf_list,
      max_x_extent = p2_areas_low_simp_max_x_extent,
      max_y_extent = p2_areas_low_simp_max_y_extent
    ),
    pattern = map(p0_states_area_info_df, p2_states_sf_list),
    iteration = "list"
  ),
  # Compute per state scale_cfg so peaks render at a fixed pixel size on each
  # state's canvas - peak_width in mm matched to the triangle base width
  tar_target(
    p2_states_scale_cfg,
    {
      target_peak_px <- 83 # pixels for max peak
      dpi <- p0_viz_config_df$dpi # 300
      canvas_w_px <- p0_viz_config_df$width
      state_aspect <- p2_states_extents_df[["x_extent"]] /
        p2_states_extents_df[["y_extent"]]
      canvas_h_px <- max(1200, min(round(canvas_w_px / state_aspect), 4800))
      state_y <- p2_states_extents_df[["y_extent"]]
      state_x <- p2_states_extents_df[["x_extent"]]
      mid_ratio <- p0_gw_binned_scales$mid_vector_height /
        p0_gw_binned_scales$max_vector_height
      min_ratio <- p0_gw_binned_scales$min_vector_height /
        p0_gw_binned_scales$max_vector_height
      # meters needed so symbol equals target_peak_px on canvas
      max_h_m <- target_peak_px * state_y / canvas_h_px
      max_w_m <- target_peak_px * state_x / canvas_w_px
      peak_width_mm <- target_peak_px / (dpi / 25.4)
      p0_gw_binned_scales |>
        mutate(
          max_vector_height = max_h_m,
          mid_vector_height = max_h_m * mid_ratio,
          min_vector_height = max_h_m * min_ratio,
          max_vector_width = max_w_m,
          mid_vector_width = max_w_m * mid_factor,
          min_vector_width = max_w_m * min_factor,
          normal_width = max_w_m * min_factor,
          max_peak_width = peak_width_mm,
          mid_peak_width = peak_width_mm * mid_factor,
          min_peak_width = peak_width_mm * min_factor
        )
    },
    pattern = map(p2_states_extents_df),
    iteration = "list"
  ),
  # Per-state viz_cfg, set canvas height to match each state's aspect ratio
  # (meters), clamped to 1200 x 4800 px.
  tar_target(
    p2_states_viz_cfg,
    {
      state_aspect <- p2_states_extents_df[["x_extent"]] /
        p2_states_extents_df[["y_extent"]]
      state_height <- round(p0_viz_config_df$width / state_aspect)
      state_height <- max(1200, min(state_height, 4800))
      p0_viz_config_df |>
        mutate(height = state_height)
    },
    pattern = map(p2_states_extents_df),
    iteration = "list"
  ),
  ##### gw data #####
  # process parquet files
  tar_target(
    # read in, process, and write out gw data
    p2_gw_clean_parquets,
    process_and_write_gw(
      gw_conditions = p1_gw_parquets_incomplete,
      output_file = sprintf(
        "2_process/out/%s.parquet",
        p1_date_incomplete[["date"]]
      ),
      scales = p0_gw_binned_scales
    ),
    pattern = map(p1_date_incomplete, p1_gw_parquets_incomplete),
    format = "file"
  )
)
