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
  # Per-state scale_cfg: use min(rel_width, rel_height) for both dimensions
  tar_target(
    p2_states_scale_cfg,
    {
      state_scale_mult <- 1
      rel_scale <- min(
        p2_states_extents_df[["rel_width"]],
        p2_states_extents_df[["rel_height"]]
      )
      p0_gw_binned_scales |>
        mutate(
          max_vector_height = max_vector_height * rel_scale * state_scale_mult,
          mid_vector_height = mid_vector_height * rel_scale * state_scale_mult,
          min_vector_height = min_vector_height * rel_scale * state_scale_mult,
          max_vector_width  = max_vector_width  * rel_scale * state_scale_mult,
          mid_vector_width  = max_vector_width * mid_factor,
          min_vector_width  = max_vector_width * min_factor,
          normal_width      = max_vector_width * min_factor,
          max_peak_width    = max_factor_mobile,
          mid_peak_width    = max_factor_mobile * mid_factor,
          min_peak_width    = max_factor_mobile * min_factor
        )
    },
    pattern = map(p2_states_extents_df),
    iteration = "list"
  ),
  
  # Per-state viz_cfg: adjust canvas height to match each state's aspect ratio
  # so the state fills the frame rather than floating in a 4800x2400 void.
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
