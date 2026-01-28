p0_targets <- list(
  tar_target(
    p0_conus_proj,
    "ESRI:102004"
    ),
  tar_target(
    p0_viz_gw_pal,
    c(
      "Extremely above" = "#313694",
      "Much above" = "#4575b4",
      "Above normal" = "#74acd1",
      "Normal" = "grey20",
      "Below normal" = "#be812b",
      "Much below" = "#8a5109",
      "Extremely below" = "#532f05")
  ),
  # OCONUS states/territories
  tar_target(
    p0_oconus_states,
    c("AK","HI","PR","VI","MP","GU","AS")
  ),
  tar_target(
    # Create a tibble to define fig width and height, conus outline colors,
    # background color, font name, and font size
    p0_viz_config_df,
    tibble(
      width = 1600,
      height = 1200,
      leg_width = 100,
      leg_height = 100,
      units = "px",
      fps = 10,
      dpi = 300,
      bg_col = "white",
      ggfx_col = "grey60",
      conus_states_col = "grey90",
      na_sites_col = "grey70",
      states_simplify = 0.9
    )
  ),
  tar_target(
    p0_gw_binned_scales,
    tibble(
      max_vector_height = 50000,
      mid_vector_height = 40000,
      min_vector_height = 30000,
      max_vector_width = 28000,
      max_factor = 1.2,
      mid_factor = 0.6,
      min_factor = 0.5,
      mid_vector_width = max_vector_width * mid_factor,
      min_vector_width = max_vector_width * min_factor,
      normal_width = max_vector_width * min_factor
    )
  )
)
