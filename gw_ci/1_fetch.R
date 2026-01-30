p1_targets <- list(
  # Load 2024 gw data
  # Note this will be swapped out down the line for more recent data (likely a parquet)
  tar_target(
    p1_gw_quantiles_2024_csv,
    "1_fetch/in/gw_daily_quantiles.csv"
    ),
  # Load 2024 gw coordinates data
  # Same note above
  tar_target(
    p1_gw_sites_2024_csv,
    "1_fetch/in/gw_site_info.csv"
    ),
  # 2024 GW data
  tar_target(
    p1_gw_conditions,
    readr::read_csv(p1_gw_quantiles_2024_csv, col_types = cols(site_no = "c"))
  ),
  tar_target(
    p1_gw_site_coords,
    readr::read_csv(p1_gw_sites_2024_csv, col_types = cols(site_no = "c")) |>
      dplyr::filter(!state_cd %in% c("02", "15", "72", "78")) |>
      sf::st_as_sf(coords = c("dec_long_va", "dec_lat_va"), crs = "EPSG:4269") |>
      sf::st_transform(crs = p0_conus_proj)
  )
)
