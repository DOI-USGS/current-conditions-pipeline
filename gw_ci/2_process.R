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
  tar_target(
    p2_conus_union,
    sf::st_union(p2_conus_states_sf)
  ),
  tar_target(
    p2_gw_conus_sf,
    {
      gw_sf <- p1_gw_parquet |>
        sf::st_transform(sf::st_crs(p2_conus_union))
      
      # Spatial filter 
      gw_conus <- gw_sf[
        sf::st_intersects(gw_sf, p2_conus_union, sparse = FALSE),
      ]
      
      # Attach state attributes 
      sf::st_join(
        gw_conus,
        p2_conus_states_sf |> dplyr::select(STUSPS, STATEFP),
        join = sf::st_intersects
      ) |>
        janitor::clean_names()
    }
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
