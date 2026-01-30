tar_source("2_process/src/process_gw_data.R")

p2_targets <- list(
  # CONUS spatial data
  tar_target(
    p2_conus_states_sf,
    tigris::states(cb = TRUE, resolution = "20m") |>
      filter(!STUSPS %in% p0_oconus_states) |>
      sf::st_transform(crs = p0_conus_proj) |>
      rmapshaper::ms_simplify(keep = p0_viz_config_df$states_simplify)
  ),
  # Extract internal lines
  tar_target(
    p2_conus_inner_states_sf,
    rmapshaper::ms_innerlines(p2_conus_states_sf)
  ),
  # extract outer boundary
  tar_target(
    p2_conus_outer_boundary_sf,
    p2_conus_states_sf |> 
      sf::st_union() |> 
      sf::st_cast("MULTILINESTRING")
  ),
  # Gather all dates
  tar_target(
    p2_gw_dates,
    p1_gw_conditions |>
      arrange(Date) |>
      pull(Date) |>
      unique()
  ),
  tar_target(
    p2_gw_processed_sf,
    process_gw_for_date(
      date = p2_gw_dates,
      gw_conditions = p1_gw_conditions,
      gw_site_coords = p1_gw_site_coords,
      scales = p0_gw_binned_scales
      ),
    pattern = map(p2_gw_dates),
    iteration = "list"
    ),
  tar_target(
    # Get subset data for legend marker creation
    p2_legend_data,
    p2_gw_processed_sf[[1]] |> 
      group_by(per_bin) |> 
      slice_head(n = 1) |> 
      ungroup()
  )
  )
