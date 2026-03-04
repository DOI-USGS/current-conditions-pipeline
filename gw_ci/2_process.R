tar_source("2_process/src/process_gw_data.R")

p2_targets <- list(
  ##### spatial data #####
  tar_target(
    p2_state_lookup,
    tigris::states(cb = TRUE, resolution = "500k") |>
      sf::st_drop_geometry() |>
      select(
        state_name_std = NAME,
        state_abbr = STUSPS
      )
  ),
  # # Filter GW data for CONUS
  # tar_target(
  #   p2_gw_conus_sf,
  #   p1_gw_parquet |> 
  #     left_join(p2_state_lookup, by = c("state_name" = "state_name_std")) |>
  #     filter(!state_abbr %in% p0_oconus_states_abbr,
  #            # Drop Marshall Islands, not US entity
  #            !state_abbr == "MH")
  # ),
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
  
  ##### spatial data #####
  # U.S. states
  # tar_target(p2_conus_oconus_sf,
  #            tigris::states(cb = TRUE) %>%
  #              st_transform(p1_proj) %>%
  #              mutate(group = case_when(
  #                STUSPS %in% c(state.abb[!state.abb %in% c('AK', 'HI')], 'DC') ~ 'CONUS',
  #                STUSPS %in% c('GU', 'MP') ~ 'GU_MP',
  #                STUSPS %in% c('PR', 'VI') ~ 'PR_VI',
  #                TRUE ~ STUSPS
  #              )) %>%
  #              filter(group %in% c('CONUS', 'AK', 'HI', 'GU_MP', 'PR_VI', 'AS'))),
  # # would need to get high- low simplifications - LIST mapping
  
  ##### gw data #####
  # process parquet files
  tar_target(
    # read in, process, and write out gw data
    p2_gw_clean_parquets,
    process_and_write_gw(
      gw_conditions = p1_gw_parquets,
      output_file = sprintf(
        "2_process/out/%s.parquet",
        p1_date_incomplete[["date"]]
        ),
      scales = p0_gw_binned_scales
      ),
    pattern = map(p1_date_incomplete, p1_gw_parquets),
    format = "file"
  )
  # ,
  # # chunk data by entity? - if yes, could combine w/ previous step
  # # for images need:
  # # desktop: CONUS, AK high simp, HI high simp, etc.
  # # mobile: CONUS, AK low simp, HI low simp, etc.
  # # so entities = CONUS, AK, HI, PR + VI, CNMI + GU, AS
  # # need list of state abbr for each entity
  # tar_target(
  #   p2_gw_sfs,
  #   # read in cleaned data, chunk by entity ? or just assign grouping field?
  #   # mutate(group = case_when(
  #   #   STUSPS %in% c(state.abb[!state.abb %in% c('AK', 'HI')], 'DC') ~ 'CONUS',
  #   #   STUSPS %in% c('GU', 'MP') ~ 'GU_MP',
  #   #   STUSPS %in% c('PR', 'VI') ~ 'PR_VI',
  #   #   TRUE ~ STUSPS
  #   # )
  #   pattern = map(p2_gw_clean_parquets),
  #   # pattern = cross(p2_gw_clean_parquets, p0_spatial_entities),
  #   iteration = "list"
  # ),
  
  # Add later 
  # tar_target(
  #   # Get subset data for legend marker creation
  #   p2_legend_data,
  #   p2_gw_clean_sf |> 
  #     group_by(per_bin) |> 
  #     slice_head(n = 1) |> 
  #     ungroup()
  # )
  )
