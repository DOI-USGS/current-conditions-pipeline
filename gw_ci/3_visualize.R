tar_source('3_visualize/src/mapping_utils.R')
tar_source('3_visualize/src/movie_utils.R')

p3_targets <- list(
  ##### Generate image files for incomplete dates #####
  
  ###### Desktop ######
  # Desktop CONUS
  tar_target(
    p3_desktop_gw_pngs,
    plot_gw_png(
      gw_parquet_file = p2_gw_clean_parquets,
      date = p1_date_incomplete[["date"]],
      area_name = "CONUS",
      # TEMPORARY BAD PRACTICE
      area_sf = p2_areas_sf_high_simp_list[[which(p0_area_info_df[["name"]] == "CONUS")]],
      area_proj = p0_area_info_df[["proj"]][[which(p0_area_info_df[["name"]] == "CONUS")]],
      area_state_list = p0_area_info_df[["state_list"]][[which(p0_area_info_df[["name"]] == "CONUS")]],
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      state_lookup = p2_state_lookup,
      image_screen_type = "desktop",
      output_template = file.path(p0_local_image_file_dir, 
                                  basename(p0_remote_image_file_template))
    ),
    pattern = map(p1_date_incomplete, p2_gw_clean_parquets),
    format = "file"
  ),
  
  ###### Mobile ######
  # Generate appropriate scaling parameters for each area
  # _NOTE: this is a first stab at adjusting these for different areas. I
  # suspect we will also need to make some further adjustments for mobile_
  tar_target(
    p3_gw_binned_scales,
    p0_gw_binned_scales |>
      mutate(
        max_vector_height = max_vector_height*p2_areas_low_simp_extents_df[["rel_height"]],
        mid_vector_height = mid_vector_height*p2_areas_low_simp_extents_df[["rel_height"]],
        min_vector_height = min_vector_height*p2_areas_low_simp_extents_df[["rel_height"]],
        max_vector_width = max_vector_width*p2_areas_low_simp_extents_df[["rel_width"]],
        mid_vector_width = max_vector_width * mid_factor,
        min_vector_width = max_vector_width * min_factor,
        normal_width = max_vector_width * min_factor
      ),
    pattern = map(p2_areas_low_simp_extents_df)
  ),
  
  # Mobile images for all areas
  tar_target(
    p3_mobile_gw_pngs,
    plot_gw_png(
      gw_parquet_file = p2_gw_clean_parquets,
      date = p1_date_incomplete[["date"]],
      area_name = p0_area_info_df[["name"]],
      area_sf = p2_areas_sf_low_simp_list,
      area_proj = p0_area_info_df[["proj"]],
      area_state_list = p0_area_info_df[["state_list"]],
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p3_gw_binned_scales,
      state_lookup = p2_state_lookup,
      image_screen_type = "mobile",
      output_template = file.path(p0_local_image_file_dir, 
                                  basename(p0_remote_image_file_template))
    ),
    pattern = 
      cross(map(p1_date_incomplete, p2_gw_clean_parquets), 
            map(p0_area_info_df, p2_areas_sf_low_simp_list, p3_gw_binned_scales)),
    format = "file"
  ),
  
  ##### Generate static stand-alone images #####
  
  # static formatted images
  # map over p3_desktop_gw_pngs (and p3_mobile_gw_pngs? see note), 
  # adding USGS logo and legend, date, etc.
  # _NOTE: may need to map over separately if generating static images for
  # all desktop and mobile views. MVP = desktop view only?_
  # _NOTE: Placeholders for these files will need to be added to p1_metadata_csv,
  # and these files will also need to be tracked in p3_new_gw_pngs_config
  # (to ensure upload to s3) and thereby in p3_date_incomplete_updated
  # (to ensure metadata updated on s3)_
  tar_target(
    p3_static_desktop_gw_pngs,
    plot_gw_static_png(
      gw_png = p3_desktop_gw_pngs,
      date = p1_date_incomplete[["date"]],
      logo_path = p0_logo_path,
      legend_path = p0_desktop_leg_path,
      viz_cfg = p0_viz_config_df,
      image_screen_type = "desktop",
      area_name = "CONUS",
      output_template = file.path(
        p0_local_image_file_dir,
        basename(p0_remote_image_file_template)
      )
    ),
    pattern = map(p1_date_incomplete, p3_desktop_gw_pngs),
    format = "file"
  ),
  
  ##### Generate legend images #####
  # Export png of each legend marker with same dimensions for website build
  tar_target(
    p3_gw_legend_pngs,
    plot_gw_leg(
      gw_parquet_file = p2_gw_clean_parquets[[1]],
      conus_proj = dplyr::filter(p0_area_info_df, name == "CONUS") |>
        pull(proj),
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      out_path = "3_visualize/out/legend/leg_%s.png"
    ),
    format = "file"
  ),
  
  ##### Recompile metadata for newly generated images ####
  
  # newly generated png config for desktop
  tar_target(
    p3_desktop_gw_pngs_config,
    tibble(
      date = p1_date_incomplete[["date"]],
      local_image_type = paste0(p0_local_image_type_prefix, 
                                "desktop_", 
                                "CONUS_image_file"),
      local_image_file = p3_desktop_gw_pngs
    )
  ),
  
  # newly generated png config for static desktop
  tar_target(
    p3_static_desktop_gw_pngs_config,
    tibble(
      date = p1_date_incomplete[["date"]],
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_static_",
        "CONUS_image_file"
      ),
      local_image_file = p3_static_desktop_gw_pngs
    )
  ),

  # newly generated png config for mobile
  tar_target(
    p3_mobile_gw_pngs_config,
    tibble(
      date = p1_date_incomplete[["date"]],
      local_image_type = paste0(p0_local_image_type_prefix, 
                                "mobile_", 
                                p0_area_info_df[["name"]], "_image_file"),
      local_image_file = p3_mobile_gw_pngs
    ),
    pattern = map(cross(p1_date_incomplete, p0_area_info_df), p3_mobile_gw_pngs)
  ),
  
  # full newly generated png config
  tar_target(
    p3_new_gw_pngs_config,
    bind_rows(p3_desktop_gw_pngs_config,
              p3_mobile_gw_pngs_config,
              p3_static_desktop_gw_pngs_config) |>
      dplyr::mutate(
        remote_image_type = stringr::str_remove(local_image_type, 
                                                p0_local_image_type_prefix),
        remote_image_file_key = gsub(p0_local_image_file_dir,
                                     dirname(p0_remote_image_file_template),
                                     local_image_file),
        newly_generated = TRUE
      )
  ),
  
  # csv with local files to be pushed to s3, with `remote_file_key`
  tar_target(
    p3_new_gw_pngs_config_csv,
    {
      outfile <- file.path("3_visualize/out", "local_pngs_for_upload.csv")
      readr::write_csv(p3_new_gw_pngs_config, outfile)
      return(outfile)
    },
    format = "file"
  ),
  
  ##### Generate mp4s for p0_intervals #####
  
  # full png config
  tar_target(
    p3_gw_pngs_config,
    dplyr::bind_rows(p1_downloaded_gw_pngs_config, p3_new_gw_pngs_config) |>
      dplyr::arrange(date)
  ),
  
  # mp4 generation for download
  # map over p0_interval_start_dates and filter p3_gw_pngs_config
  # TBD: how to handle different areas??? do we want mp4s for every area?
  # MVP: filter to local_image_type == local_desktop_CONUS_image_file?
  # combine all of filtered_df[["local_image_file"]] into mp4, adding USGS logo
  # and legend, date, etc.
  tar_target(
    p3_gw_desktop_mp4,
    build_gw_mp4(
      interval_start_date = p0_interval_start_dates,
      gw_png_config = p3_gw_pngs_config,
      viz_cfg = p0_viz_config_df,
      out_dir = p0_local_image_file_dir
    ),
    pattern = map(p0_interval_start_dates),
    format = "file"
  ),
  
  tar_target(
    p3_gw_mp4_config,
    tibble::tibble(
      date = p0_interval_start_dates,
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_static_CONUS_mp4_",
        format(p0_interval_start_dates, "%Y%m%d")
      ),
      local_image_file = p3_gw_desktop_mp4
    ),
    pattern = map(p0_interval_start_dates)
  ),
  
  tar_target(
    p3_new_gw_mp4_config,
    p3_gw_mp4_config |>
      dplyr::mutate(
        remote_image_type =
          stringr::str_remove(local_image_type, p0_local_image_type_prefix),
        remote_image_file_key =
          gsub(
            p0_local_image_file_dir,
            dirname(p0_remote_image_file_template),
            local_image_file
          ),
        newly_generated = TRUE
      )
  ),
  
  tar_target(
    p3_new_gw_files_config,
    dplyr::bind_rows(
      p3_new_gw_pngs_config,
      p3_new_gw_mp4_config
    )
  ),
  
  ##### Generate updated metadata file to be pushed to s3 #####
  
  # Get updated version of p1_incomplete w/ remote file keys for new images
  # _NOTE: Not sure this is the best way to build this, but wanted to be sure
  # to retain the original column names and order_
  tar_target(
    p3_date_incomplete_updated,
    p1_date_incomplete |>
      dplyr::select(-complete) |>
      tidyr::pivot_longer(cols = matches("(image_file|mp4)"), 
                   names_to = "remote_image_type",
                   values_to = "remote_image_file_key") |>
      # Drop column `remote_image_key` since by default NA for incomplete dates
      dplyr::select(-c(remote_image_file_key)) |>
      # Join in info on remote files based on locally generated files
      dplyr::left_join(p3_new_gw_files_config |>
                         select(date, remote_image_type, remote_image_file_key),
                       by = c("date", "remote_image_type")
                       ) |> 
      # Pivot back to wide to match original format
      tidyr::pivot_wider(names_from = remote_image_type,
                         values_from = remote_image_file_key,
                         values_fn = dplyr::first
      )
  ),
  
  # Final update metadata file
  # WILL NEED TO ACCOUNT FOR MORE FILES - MP4 and static formatted images
  tar_target(
    p3_date_config_updated_csv,
    {
      outfile <- file.path("3_visualize/out", basename(p1_metadata_csv))
      dplyr::bind_rows(
        dplyr::select(p1_date_complete, -complete), 
        p3_date_incomplete_updated
      ) |>
        dplyr::arrange(date) |>
        readr::write_csv(outfile)
      return(outfile)
    },
    format = "file"
  )
)
