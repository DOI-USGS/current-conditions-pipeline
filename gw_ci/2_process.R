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
    {
      # filter p1_states_sf to single state using p0_states_area_info_df[["state_list"]]
      # reproject to p0_states_area_info_df[["proj"]] (EPSG:5070)
      # simplify using p0_states_area_info_df[["simplification_keep_low_simp"]]
      # return sf object for single state
      message(sprintf(
        "State polygons for %s, project to %s, and simplify geometry",
        p0_states_area_info_df[["name"]],
        p0_states_area_info_df[["proj"]]
        ))
      },
    pattern = map(p0_states_area_info_df),
    iteration = "list"
  ),
  
  tar_target(
    p2_states_extents_df,
    {
      # use:
      #   - single state row from p0_states_area_info_df
      #   - single state sf object from p2_states_sf_list
      #   - p2_areas_low_simp_max_x_extent 
      #   - p2_areas_low_simp_max_y_extent 
      #
      # compute extent information needed for plotting
      # including:
      #   - x_extent
      #   - y_extent
      #   - rel_width = state x_extent / CONUS x_extent
      #   - rel_height = state y_extent / CONUS y_extent
      #
      # this ensures symbol scaling is consistent with CONUS logic
      # used in mobile and other area-based plots
      #
      # return single-row extent list for the state
      message(sprintf(
        "Build plotting extent for %s using CONUS reference extents for scaling",
        p0_states_area_info_df[["name"]]
      ))
    },
    pattern = map(p0_states_area_info_df, p2_states_sf_list),
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
