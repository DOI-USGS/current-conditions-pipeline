p1_targets <- list(
  # Load in yesterday's GW conditions parquet file
  tar_target(
    p1_gw_url,
    paste0(
      "https://labs.waterdata.usgs.gov/visualizations/current_conditions/groundwater/stage/gw_categorizations_",
      format(p0_yesterday_date, "%Y-%m-%d"),
      ".parquet"
      )
    ),
  tar_target(
    p1_gw_file,
    {
      out <- file.path("1_fetch/out", basename(p1_gw_url))
      download.file(p1_gw_url, out, mode = "wb")
      out
    },
    format = "file"
  ),
  tar_target(
    p1_gw_parquet,
    arrow::read_parquet(p1_gw_file) |> 
      sf::st_as_sf() |>
      sf::st_set_crs(sf::st_crs("EPSG:4326")) |> 
      st_transform(p0_conus_proj)
  )
)
