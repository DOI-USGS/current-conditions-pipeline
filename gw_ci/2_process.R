tar_source("2_process/src/process_gw_data.R")

p2_targets <- list(
  tar_target(
    p2_gw_processed_sf,
    process_gw_for_date(
      date = p1_gw_dates,
      gw_conditions = p1_gw_conditions,
      gw_site_coords = p1_gw_site_coords,
      scales = p0_gw_binned_scales
      ),
    pattern = map(p1_gw_dates),
    iteration = "list"
    )
  )
