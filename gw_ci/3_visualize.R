tar_source('3_visualize/src/mapping_utils.R')

p3_targets <- list(
  # go straight for checking if image files exist on s3
  # # would require 1 target per png type (e.g., desktop_CONUS_OCONUS, mobile_CONUS, mobile_AK)
  # # would have side effect of downloading parquet file
  # # lots of steps buried in fxn (plot data on top of state data, arrange in layout, save as png)
  # tar_target(
  #   p3_gw_pngs,
  #   {
  #     # If the image file exists on s3, download it
  #     if (!is.na(p1_date_config[["image_file"]])) {
  #       message(sprintf("Downloading %s", p1_date_config[["remote_image_file"]]))
  #     }
  #     # If it doesn't exist on s3, make it
  #     else {
  #       message(sprintf("Generating image for %s", p1_date_config[["date"]]))
  #       # download p1_date_config[["remote_parquet_file"]]
  #       # read in and process data
  #       # plot data (requires correct spatial input)
  #       # save as png
  #     }
  #   },
  #   pattern = map(p1_date_config)
  # ),
  # OR do incomplete/complete binning
  
  # incomplete - CONUS
  tar_target(
    p3_new_gw_pngs,
    plot_conus_gw_pngs(
      gw_parquet_file = p2_gw_clean_parquets,
      date = p1_date_incomplete[["date"]],
      conus_states = p2_conus_states_sf,
      conus_inner_states_sf = p2_conus_inner_states_sf,
      conus_outer_states_sf = p2_conus_outer_boundary_sf,
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      state_lookup = p2_state_lookup,
      oconus_abbr = p0_oconus_states_abbr,
      conus_proj = p0_conus_proj,
      output_template = p0_local_image_file_template
    ),
    pattern = map(p1_date_incomplete, p2_gw_clean_parquets),
    format = "file"
  ),
  
  # Export png of each legend marker with same dimensions for website build
  tar_target(
    p3_gw_legend_pngs,
    plot_gw_leg(
      gw_parquet_file = p2_gw_clean_parquets[[1]],
      conus_proj = p0_conus_proj,
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      out_path = "3_visualize/out/legend/leg_%s.png"
    ),
    format = "file"
  ), 
  
  # incomplete tibble for CONUS
  tar_target(
    p3_new_png_config,
    p1_date_incomplete |>
      mutate(
        local_image_file = p3_new_gw_pngs,
        # local_image_hash = tools::md5sum(local_image_file),
        image_file = sprintf(p0_remote_image_file_template, date),
        remote_image_file_URL = paste0(p0_s3_prod_URL, image_file)
      )
  ),
  
  # final tibble for CONUS
  # populate local_image_file for one that already existed
  # WILL NEED TO ACCOUNT FOR MORE FILES - MP4 and static formatted images
  tar_target(
    p3_date_config_revised,
    bind_rows(p1_date_complete, p3_new_png_config) |>
      arrange(date)
  )
  #,
  
  # mp4 generation for download
  # map over p0_interval_start_dates and filter p3_date_config_revised
  # combine all of filtered_df[["local_image_file"]] into mp4, adding USGS logo
  # and legend, date, etc.
  
  # static formatted images
  # map over p0_interval_start_dates, adding USGS logo and legend, date, etc.
  
  
  # incomplete - all areas
  # desktop
  # p3_new_gw_desktop_pngs
  ## plot gw data, passing high simplification spatial data for all entities (list), data for one date p2_gw_sfs/p2_gw_clean_parquets
  ## in fxn, generate list of plots for each entity
  ## then pass plots to layout fxn
  ## save as png
  ## map over: p2_gw_sfs/p2_gw_clean_parquets - single png returned for each date
  ## file target - length = length of p1_date_incomplete
  # mobile
  # p3_new_gw_mobile_pngs
  ## plot gw data, passing low simplification spatial data for single entity, data for one date
  ## in fxn, generate plot for that entity (filter data, and project for that entity)
  ## pass to simple layout fxn
  ## save as png
  ## map over: cross(map(p2_gw_sfs/p2_gw_clean_parquets, p1_date_incomplete), low_simp_spatial_data)
  ## file target - length = p1_date_incomplete * length of low_simp_spatial_data
  
  ## incomplete png tibble for desktop
  # tibble, date = p1_date_incomplete, desktop_image_file = p3_new_gw_desktop_pngs
  
  ## incomplete png tibble for mobile
  # tibble, date = p1_date_incomplete, mobile_image_file = p3_new_gw_mobile_pngs
  # map over: p3_new_gw_mobile_pngs

  )
