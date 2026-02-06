tar_source('3_visualize/src/mapping_utils.R')

p3_targets <- list(
  tar_target(
    # Build gw frames
    p3_gw_frame_pngs,
    plot_gw_frame(
      gw_sf = p2_gw_processed_sf,
      date = p2_gw_dates,
      conus_states = p2_conus_states_sf,
      conus_inner_states_sf = p2_conus_inner_states_sf,
      conus_outer_states_sf = p2_conus_outer_boundary_sf,
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      out_path = glue::glue("3_visualize/out/gw/gw_{p2_gw_dates}.png")
      ),
    pattern = map(p2_gw_processed_sf, p2_gw_dates),
    format = "file"
    ),
  tar_target(
    # Create gw animation mp4 format
    p3_gw_mp4,
    {
      av::av_encode_video(
        input = p3_gw_frame_pngs,
        output = "3_visualize/out/gw/gw_binned_scaled_glow_peak.mp4",
        framerate = p0_viz_config_df$fps,
        vfilter = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
      )
    },
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
        out_pat = glue::glue("3_visualize/out/legend/leg_{file_id}.png")
      )
    },
    pattern = map(p2_legend_data),
    format = "file"
  )
)
