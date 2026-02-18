tar_source("2_process/src/process_gw_data.R")

p2_targets <- list(
  tar_target(
    p2_state_lookup,
    tigris::states(cb = TRUE, resolution = "500k") |>
      sf::st_drop_geometry() |>
      select(
        state_name_std = NAME,
        state_abbr = STUSPS
      ) |>
      # Add Marshall Islands since tigris::states() does not have it
      bind_rows(
        tibble::tibble(
          state_name_std = "Marshall Islands",
          state_abbr = "MH"
        )
      )
  ),
  # Filter GW data for CONUS
  tar_target(
    p2_gw_conus_sf,
    p1_gw_parquet |> 
      left_join(p2_state_lookup, by = c("state_name" = "state_name_std")) |>
      filter(!state_abbr %in% p0_oconus_states_abbr)
  ),
  # CONUS spatial data
  tar_target(
    p2_conus_states_sf,
    tigris::states(cb = TRUE, resolution = "20m") |>
      filter(!STUSPS %in% p0_oconus_states_abbr) |>
      sf::st_transform(crs = p0_conus_proj) |>
      rmapshaper::ms_simplify(keep = p0_viz_config_df$states_simplify)
  ),
  # Extract internal lines
  tar_target(
    p2_conus_inner_states_sf,
    rmapshaper::ms_innerlines(p2_conus_states_sf)
  ),
  # Extract outer boundary
  tar_target(
    p2_conus_outer_boundary_sf,
    p2_conus_states_sf |> 
      sf::st_union() |> 
      sf::st_cast("MULTILINESTRING")
  ),
  # Clean up gw 
  tar_target(
    p2_gw_clean_sf,
    process_gw_join(
      gw_conditions = p2_gw_conus_sf,
      scales = p0_gw_binned_scales
    )
  ),
  tar_target(
    # Get subset data for legend marker creation
    p2_legend_data,
    p2_gw_clean_sf |> 
      group_by(per_bin) |> 
      slice_head(n = 1) |> 
      ungroup()
  )
  )
