tar_source('3_visualize/src/mapping_utils.R')

p3_targets <- list(
  tar_target(
    # Build gw frames
    p3_gw_frame_png,
    plot_gw_frame(
      gw_sf = p2_gw_processed_sf,
      date = plot_date,
      conus_states_sf = p1_conus_states_sf,
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      out_path = glue::glue("3_visualize/out/gw/gw_{p2_gw_processed_sf %>% pull(Date) %>% .[1]}.png")
      ),
    pattern = map(p2_gw_processed_sf),
    format = "file"
    ),
  tar_target(
    # Create gw animation mp4 format
    p3_gw_mp4,
    {
      # sort to ensure the video isn't jumbled
      av::av_encode_video(
        input = sort(p3_gw_frame_png),
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
      # all categories plus NA
      marker_cats <- c(names(p0_viz_gw_pal), "NA_site")

      purrr::map_chr(marker_cats, function(cat) {
        file_id <- janitor::make_clean_names(cat)
        # or if you'd prefer svg -> `...svg`
        out <- glue::glue("3_visualize/out/legend/leg_{file_id}.png")

        plot_gw_leg(
          category = ifelse(cat == "NA_site", NA_character_, cat),
          palette = p0_viz_gw_pal,
          viz_cfg = p0_viz_config_df,
          scale_cfg = p0_gw_binned_scales,
          out_path = out
        )
      })
    },
    format = "file"
  )
)
