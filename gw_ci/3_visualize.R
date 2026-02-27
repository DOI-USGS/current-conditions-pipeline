tar_source('3_visualize/src/mapping_utils.R')

p3_targets <- list(
  tar_target(
    # Build gw frames
    p3_gw_frame_png,
    plot_gw_frame(
      gw_sf = p2_gw_clean_sf,
      date = p0_yesterday_date,
      conus_states = p2_conus_states_sf,
      conus_inner_states_sf = p2_conus_inner_states_sf,
      conus_outer_states_sf = p2_conus_outer_boundary_sf,
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      out_path = glue::glue("3_visualize/out/gw/gw_{p0_yesterday_date}.png")
      ),
    format = "file"
    ),
  # Export png of each legend marker with same dimensions for website build
  tar_target(
    p3_gw_legend_pngs,
    {
      # Handle the filenames
      cat_name <- ifelse(is.na(p2_legend_data$per_bin), "na_site", p2_legend_data$per_bin)
      file_id <- janitor::make_clean_names(cat_name)

      plot_gw_leg(
        leg_row = p2_legend_data,
        palette = p0_viz_gw_pal,
        viz_cfg = p0_viz_config_df,
        scale_cfg = p0_gw_binned_scales,
        out_path = glue::glue("3_visualize/out/legend/leg_{file_id}.png")
      )
    },
    pattern = map(p2_legend_data),
    format = "file"
  ),
  # uplaod image to S3 bucket
  tar_target(
    p3_gw_frame_s3,
    # Make note of how to access S3 bucket in ReadME
    upload_to_s3(
      bucket = "water-visualizations-prod-website",
      local_file = p3_gw_frame_png,
      date = p0_yesterday_date)
  )
  )
