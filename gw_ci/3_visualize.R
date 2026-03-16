tar_source('3_visualize/src/mapping_utils.R')
tar_source('3_visualize/src/locator_map.R')
tar_source('3_visualize/src/landscape_condensed.R')
tar_source('3_visualize/src/movie_utils.R')

p3_targets <- list(
  ##### Generate image files for incomplete dates #####
  
  ###### Desktop ######
  # Desktop CONUS + OCONUS
  tar_target(
    p3_desktop_locator_map_png,
    generate_extent_locator_map(
      area_name = p0_desktop_area_name,
      # Full map scene
      in_map = dplyr::bind_rows(p2_areas_sf_high_simp_wgs84_list),
      # Countries of interest to map
      add_sf = p2_areas_sf_high_simp_wgs84_list,
      shift_longitude = TRUE,
      graticules = 30,
      add_sf_ext = TRUE,
      buffer_m_add_sf = 130000,
      viz_cfg = p0_viz_config_df,
      output_template = file.path(p0_local_image_file_dir,
                                  p0_locator_map_template)
    ),
    format = "file"
  ),
  tar_target(
    p3_desktop_gw_pngs,
    plot_gw_png(
      gw_parquet_file = p2_gw_clean_parquets,
      date = p1_date_incomplete[["date"]],
      area_name = p0_desktop_area_name,
      area_info_df = p0_area_info_df,
      area_sf = p2_areas_sf_high_simp_list,
      extent_info = p2_areas_high_simp_extents_df,
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      state_lookup = p2_state_lookup,
      locator_map_png = p3_desktop_locator_map_png,
      image_screen_type = "desktop",
      output_template = file.path(p0_local_image_file_dir, 
                                  basename(p0_remote_image_file_template))
    ),
    pattern = map(p1_date_incomplete, p2_gw_clean_parquets),
    format = "file"
  ),
  
  ###### Mobile ######
  # Mobile images for all areas
  tar_target(
    p3_mobile_gw_pngs,
    plot_gw_png(
      gw_parquet_file = p2_gw_clean_parquets,
      date = p1_date_incomplete[["date"]],
      area_name = p0_area_info_df[["name"]],
      area_info_df = p0_area_info_df,
      area_sf = p2_areas_sf_low_simp_list,
      extent_info = p2_areas_low_simp_extents_df,
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      state_lookup = p2_state_lookup,
      image_screen_type = "mobile",
      output_template = file.path(p0_local_image_file_dir, 
                                  basename(p0_remote_image_file_template))
    ),
    pattern = 
      cross(map(p1_date_incomplete, p2_gw_clean_parquets), 
            map(p0_area_info_df, p2_areas_sf_low_simp_list, p2_areas_low_simp_extents_df)),
    format = "file"
  ),
  
  ##### Generate static stand-alone images #####
  
  # Static formatted images
  tar_target(
    p3_static_gw_pngs,
    plot_gw_static_png(
      gw_png = p3_desktop_gw_pngs,
      date = p1_date_incomplete[["date"]],
      logo_path = p0_logo_path,
      legend_path = p0_desktop_leg_path,
      viz_cfg = p0_viz_config_df,
      image_screen_type = "desktop",
      area_name = p0_desktop_area_name,
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
                                p0_desktop_area_name,
                                "_image_file"),
      local_image_file = p3_desktop_gw_pngs
    )
  ),
  
  # newly generated png config for static desktop
  tar_target(
    p3_static_gw_pngs_config,
    tibble(
      date = p1_date_incomplete[["date"]],
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_static_",
        p0_desktop_area_name,
        "_image_file"
      ),
      local_image_file = p3_static_gw_pngs
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
              p3_static_gw_pngs_config) |>
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
  tar_target(
    p3_gw_desktop_mp4,
    build_gw_mp4(
      interval_start_date = p0_interval_start_dates,
      interval_end_date = p0_yesterday_date,
      interval_name = p0_interval_names,
      gw_png_config = p3_gw_pngs_config,
      viz_cfg = p0_viz_config_df,
      img_type_name = paste0(
        "local_desktop_static_",
        p0_desktop_area_name,
        "_image_file"),
      output_template = file.path(p0_local_image_file_dir, 
                                  sprintf("gw-movie-desktop-%s-%s.mp4",
                                          p0_desktop_area_name,
                                          p0_interval_names))
      ),
    pattern = map(p0_interval_start_dates, p0_interval_names),
    format = "file"
    ),
  
  tar_target(
    p3_new_gw_mp4_config,
    tibble::tibble(
      date = p0_yesterday_date,
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_static_",
        p0_desktop_area_name,
        "_mp4_",
        gsub("-", "_", p0_interval_names)
      ),
      local_image_file = p3_gw_desktop_mp4
    ) |>
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
  )
)
