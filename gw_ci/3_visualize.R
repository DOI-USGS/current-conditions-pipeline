tar_source('3_visualize/src/mapping_utils.R')
tar_source('3_visualize/src/locator_map.R')
tar_source('3_visualize/src/landscape_condensed.R')
tar_source('3_visualize/src/movie_utils.R')

p3_targets <- list(
  ##### Generate image files for incomplete dates #####
  
  ###### Desktop CONUS + OCONUS ######
  # Locator map
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
  
  # Desktop foreground webp for website rendering
  tar_target(
    p3_desktop_CONUS_OCONUS_gw_webps,
    plot_gw_image(
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
      locator_map_png = NULL,
      image_screen_type = "desktop",
      layer_mode = "foreground",
      output_format = "webp",
      transparent_bg = TRUE,
      output_template = file.path(
        p0_local_image_file_dir,
        gsub("\\.png$", ".webp", basename(p0_remote_image_file_template))
      )
    ),
    pattern = map(p1_date_incomplete, p2_gw_clean_parquets),
    format = "file"
  ),
  
  # Desktop background webp for website rendering
  tar_target(
    p3_desktop_CONUS_OCONUS_bkgd_webps,
    {
      out <- file.path(
        p0_local_image_file_dir,
        sprintf("gw-%s-%s-background.webp", "desktop", p0_desktop_area_name)
      )
      # Download the background from S3 if it exists; otherwise create it.
      if (!download_gw_bkgd_if_exists(out, p0_s3_prod_URL,
                                      p0_remote_image_file_template)) {
        plot_gw_image(
          gw_parquet_file = NA_character_,
          date = p0_yesterday_date, 
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
          layer_mode = "background",
          output_format = "webp",
          transparent_bg = TRUE,
          output_template = out
        )
      }
      out
    },
    format = "file"
  ),
  
  ###### Desktop CONUS, AK, HI, major territories ######
  # Desktop foreground webp for website rendering
  tar_target(
    p3_desktop_CONUS_AK_HI_territories_gw_webps,
    plot_gw_image(
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
      image_screen_type = "desktop",
      layer_mode = "foreground",
      output_format = "webp",
      transparent_bg = TRUE,
      output_template = file.path(
        p0_local_image_file_dir,
        gsub("\\.png$", ".webp", basename(p0_remote_image_file_template))
      )
    ),
    pattern = cross(
      map(p1_date_incomplete, p2_gw_clean_parquets),
      map(p0_area_info_df, p2_areas_sf_low_simp_list, p2_areas_low_simp_extents_df)
    ),
    format = "file"
  ),
  
  # Desktop background webp for website rending
  tar_target(
    p3_desktop_CONUS_AK_HI_territories_bkgd_webps,
    {
      out <- file.path(
        p0_local_image_file_dir,
        sprintf("gw-%s-%s-background.webp", "desktop", p0_area_info_df[["name"]])
      )
      # Download the background from S3 if it exists; otherwise create it.
      if (!download_gw_bkgd_if_exists(out, p0_s3_prod_URL,
                                      p0_remote_image_file_template)) {
        plot_gw_image(
          gw_parquet_file = NA_character_,   
          date = p0_yesterday_date,         
          area_name = p0_area_info_df[["name"]],
          area_info_df = p0_area_info_df,
          area_sf = p2_areas_sf_low_simp_list,
          extent_info = p2_areas_low_simp_extents_df,
          palette = p0_viz_gw_pal,
          viz_cfg = p0_viz_config_df,
          scale_cfg = p0_gw_binned_scales,
          state_lookup = p2_state_lookup,
          locator_map_png = NULL,
          image_screen_type = "desktop",
          layer_mode = "background",
          output_format = "webp",
          transparent_bg = TRUE,
          output_template = out
        )
      }
      out
    },
    pattern = cross(
      map(p0_area_info_df, p2_areas_sf_low_simp_list, p2_areas_low_simp_extents_df)
    ),
    format = "file"
  ),
  
  ###### Desktop lower 48 states images #####
  # State foreground webps, branched by state x date
  tar_target(
    p3_desktop_lower_48_gw_webps,
    plot_gw_image(
      gw_parquet_file = p2_gw_clean_parquets,
      date = p1_date_incomplete[["date"]],
      area_name = p0_states_area_info_df[["name"]],
      area_info_df = p0_states_area_info_df,
      area_sf = p2_states_sf_list,
      extent_info = p2_states_extents_df,
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      state_lookup = p2_state_lookup,
      locator_map_png = NULL,
      image_screen_type = "desktop",
      layer_mode = "foreground",
      output_format = "webp",
      transparent_bg = TRUE,
      output_template = file.path(
        p0_local_image_file_dir,
        gsub("\\.png$", ".webp", basename(p0_remote_image_file_template))
      )
    ),
    pattern = cross(
      map(p1_date_incomplete, p2_gw_clean_parquets),
      map(p0_states_area_info_df, p2_states_sf_list, p2_states_extents_df)
    ),
    format = "file"
  ),
  
  # State background webps, one per state, not date branched
  tar_target(
    p3_desktop_lower_48_bkgd_webps,
    {
      out <- file.path(
        p0_local_image_file_dir,
        sprintf("gw-%s-%s-background.webp", "desktop",
                p0_states_area_info_df[["name"]])
      )
      # Download the background from S3 if it exists; otherwise create it.
      if (!download_gw_bkgd_if_exists(out, p0_s3_prod_URL,
                                      p0_remote_image_file_template)) {
        plot_gw_image(
          gw_parquet_file = NA_character_,
          date = p0_yesterday_date,         
          area_name = p0_states_area_info_df[["name"]],
          area_info_df = p0_states_area_info_df,
          area_sf = p2_states_sf_list,
          extent_info = p2_states_extents_df,
          palette = p0_viz_gw_pal,
          viz_cfg = p0_viz_config_df,
          scale_cfg = p0_gw_binned_scales,
          state_lookup = p2_state_lookup,
          locator_map_png = NULL,
          image_screen_type = "desktop",
          layer_mode = "background",
          output_format = "webp",
          transparent_bg = TRUE,
          output_template = out
        )
      }
      out
    },
    pattern = map(p0_states_area_info_df, p2_states_sf_list,
                  p2_states_extents_df),
    format = "file"
  ),
  
  ###### Mobile CONUS, AK, HI, major territories ######
  # Mobile foreground webp for website rendering
  tar_target(
    p3_mobile_CONUS_AK_HI_territories_gw_webps,
    plot_gw_image(
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
      layer_mode = "foreground",
      output_format = "webp",
      transparent_bg = TRUE,
      output_template = file.path(
        p0_local_image_file_dir,
        gsub("\\.png$", ".webp", basename(p0_remote_image_file_template))
      )
    ),
    pattern = cross(
      map(p1_date_incomplete, p2_gw_clean_parquets),
      map(p0_area_info_df, p2_areas_sf_low_simp_list, p2_areas_low_simp_extents_df)
    ),
    format = "file"
  ),
  
  # Mobile background webp for website rending
  tar_target(
    p3_mobile_CONUS_AK_HI_territories_bkgd_webps,
    {
      out <- file.path(
        p0_local_image_file_dir,
        sprintf("gw-%s-%s-background.webp", "mobile", p0_area_info_df[["name"]])
      )
      # Download the background from S3 if it exists; otherwise create it.
      if (!download_gw_bkgd_if_exists(out, p0_s3_prod_URL,
                                      p0_remote_image_file_template)) {
        plot_gw_image(
          gw_parquet_file = NA_character_,
          date = p0_yesterday_date,
          area_name = p0_area_info_df[["name"]],
          area_info_df = p0_area_info_df,
          area_sf = p2_areas_sf_low_simp_list,
          extent_info = p2_areas_low_simp_extents_df,
          palette = p0_viz_gw_pal,
          viz_cfg = p0_viz_config_df,
          scale_cfg = p0_gw_binned_scales,
          state_lookup = p2_state_lookup,
          locator_map_png = NULL,
          image_screen_type = "mobile",
          layer_mode = "background",
          output_format = "webp",
          transparent_bg = TRUE,
          output_template = out
        )
      }
      out
    },
    pattern = cross(
      map(p0_area_info_df, p2_areas_sf_low_simp_list, p2_areas_low_simp_extents_df)
    ),
    format = "file"
  ),
  
  ###### Mobile lower 48 states images #####
  # State foreground webps, branched by state x date
  tar_target(
    p3_mobile_lower_48_gw_webps,
    plot_gw_image(
      gw_parquet_file = p2_gw_clean_parquets,
      date = p1_date_incomplete[["date"]],
      area_name = p0_states_area_info_df[["name"]],
      area_info_df = p0_states_area_info_df,
      area_sf = p2_states_sf_list,
      extent_info = p2_states_extents_df,
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      state_lookup = p2_state_lookup,
      locator_map_png = NULL,
      image_screen_type = "mobile",
      layer_mode = "foreground",
      output_format = "webp",
      transparent_bg = TRUE,
      output_template = file.path(
        p0_local_image_file_dir,
        gsub("\\.png$", ".webp", basename(p0_remote_image_file_template))
      )
    ),
    pattern = cross(
      map(p1_date_incomplete, p2_gw_clean_parquets),
      map(p0_states_area_info_df, p2_states_sf_list, p2_states_extents_df)
    ),
    format = "file"
  ),
  
  # State background webps, one per state, not date branched
  tar_target(
    p3_mobile_lower_48_bkgd_webps,
    {
      out <- file.path(
        p0_local_image_file_dir,
        sprintf("gw-%s-%s-background.webp", "mobile",
                p0_states_area_info_df[["name"]])
      )
      # Download the background from S3 if it exists; otherwise create it.
      if (!download_gw_bkgd_if_exists(out, p0_s3_prod_URL,
                                      p0_remote_image_file_template)) {
        plot_gw_image(
          gw_parquet_file = NA_character_,
          date = p0_yesterday_date,          
          area_name = p0_states_area_info_df[["name"]],
          area_info_df = p0_states_area_info_df,
          area_sf = p2_states_sf_list,
          extent_info = p2_states_extents_df,
          palette = p0_viz_gw_pal,
          viz_cfg = p0_viz_config_df,
          scale_cfg = p0_gw_binned_scales,
          state_lookup = p2_state_lookup,
          locator_map_png = NULL,
          image_screen_type = "mobile",
          layer_mode = "background",
          output_format = "webp",
          transparent_bg = TRUE,
          output_template = out
        )
      }
      out
    },
    pattern = map(p0_states_area_info_df, p2_states_sf_list,
                  p2_states_extents_df),
    format = "file"
  ),
  
  ##### Generate static stand-alone images #####
  
  # Static CONUS_OCONUS formatted images
  tar_target(
    p3_static_CONUS_OCONUS_gw_pngs,
    plot_gw_static_png(
      gw_bkgd_img = p3_desktop_CONUS_OCONUS_bkgd_webps,
      gw_frgd_img = p3_desktop_CONUS_OCONUS_gw_webps,  
      date = p1_date_incomplete[["date"]],
      logo_path = p0_logo_path,
      legend_path = p1_desktop_legend_svg,
      viz_cfg = p0_viz_config_df,
      image_screen_type = "desktop",
      area_name = p0_desktop_area_name,
      output_template = file.path(
        p0_local_image_file_dir,
        basename(p0_remote_image_file_template)
      )
    ),
    pattern = map(p1_date_incomplete, p3_desktop_CONUS_OCONUS_gw_webps),
    format = "file"
  ),
  
  # # Lower 48 states formatted images
  # tar_target(
  #   p3_static_lower_48_gw_pngs,
  #   plot_gw_static_png(
  #     gw_bkgd_img = p3_desktop_lower_48_bkgd_webps,
  #     gw_frgd_img = p3_desktop_lower_48_gw_webps,
  #     date = p1_date_incomplete[["date"]],
  #     logo_path = p0_logo_path,
  #     legend_path = p0_desktop_leg_path,
  #     viz_cfg = p0_viz_config_df,
  #     image_screen_type = "desktop",
  #     area_name = p0_states_area_info_df[["name"]],
  #     output_template = file.path(
  #       p0_local_image_file_dir,
  #       basename(p0_remote_image_file_template)
  #     )
  #   ),
  #   pattern = map(
  #     p3_desktop_lower_48_gw_webps,
  #     cross(p1_date_incomplete, map(p0_states_area_info_df, p3_desktop_lower_48_bkgd_webps))
  #   ),
  #   format = "file"
  # ),
  
  ##### Generate legend images #####
  # Export svg of each legend marker with same dimensions for website build
  tar_target(
    p3_gw_legend_svgs,
    plot_gw_leg(
      gw_parquet_file = p2_gw_clean_parquets[[1]],
      conus_proj = filter(p0_area_info_df, name == "CONUS") |>
        pull(proj),
      palette = p0_viz_gw_pal,
      viz_cfg = p0_viz_config_df,
      scale_cfg = p0_gw_binned_scales,
      out_path = "3_visualize/out/legend/leg_%s.svg"
    ),
    format = "file"
  ),
  
  ##### Recompile metadata for newly generated images ####
  
  ###### Desktop images ######
  # Desktop CONUS_OCONUS foreground webp config
  tar_target(
    p3_desktop_CONUS_OCONUS_gw_webps_config,
    tibble(
      date = p1_date_incomplete[["date"]],
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_",
        p0_desktop_area_name,
        "_image_file"
      ),
      local_image_file = p3_desktop_CONUS_OCONUS_gw_webps
    )
  ),
  
  # Desktop CONUS_OCONUS background webp config
  tar_target(
    p3_desktop_CONUS_OCONUS_bkgd_webps_config,
    tibble(
      # not date specific
      date = NA,  
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_",
        p0_desktop_area_name,
        "_background_webp"
      ),
      local_image_file = p3_desktop_CONUS_OCONUS_bkgd_webps
    )
  ),
  
  # Desktop CONUS, AK, HI, major territories foreground webp config
  tar_target(
    p3_desktop_CONUS_AK_HI_territories_gw_webps_config,
    tibble(
      date = p1_date_incomplete[["date"]],
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_",
        p0_area_info_df[["name"]],
        "_image_file"
      ),
      local_image_file = p3_desktop_CONUS_AK_HI_territories_gw_webps
    ),
    pattern = map(
      cross(p1_date_incomplete, p0_area_info_df),
      p3_desktop_CONUS_AK_HI_territories_gw_webps
    )
  ),
  
  # Desktop CONUS, AK, HI, major territories background webp config
  tar_target(
    p3_desktop_CONUS_AK_HI_territories_bkgd_webps_config,
    tibble(
      # not date specific
      date = NA,
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_",
        p0_area_info_df[["name"]],
        "_background_webp"
      ),
      local_image_file = p3_desktop_CONUS_AK_HI_territories_bkgd_webps
    ),
    pattern = map(p0_area_info_df, p3_desktop_CONUS_AK_HI_territories_bkgd_webps)
  ),
  
  # Desktop lower 48 states foreground webp config
  tar_target(
    p3_desktop_lower_48_gw_webps_config,
    tibble(
      date = p1_date_incomplete[["date"]],
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_",
        p0_states_area_info_df[["name"]],
        "_image_file"
      ),
      local_image_file = p3_desktop_lower_48_gw_webps
    ),
    pattern = map(
      cross(p1_date_incomplete, p0_states_area_info_df),
      p3_desktop_lower_48_gw_webps
    )
  ),
  
  # Desktop lower 48 states background webp config
  tar_target(
    p3_desktop_lower_48_bkgd_webps_config,
    tibble(
      date = NA,
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_",
        p0_states_area_info_df[["name"]],
        "_background_webp"
      ),
      local_image_file = p3_desktop_lower_48_bkgd_webps
    ),
    pattern = map(p0_states_area_info_df, p3_desktop_lower_48_bkgd_webps)
  ),

  ###### Mobile images ######
  # Mobile CONUS, AK, HI, major territories foreground webp config
  tar_target(
    p3_mobile_CONUS_AK_HI_territories_gw_webps_config,
    tibble(
      date = p1_date_incomplete[["date"]],
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "mobile_",
        p0_area_info_df[["name"]],
        "_image_file"
      ),
      local_image_file = p3_mobile_CONUS_AK_HI_territories_gw_webps
    ),
    pattern = map(
      cross(p1_date_incomplete, p0_area_info_df),
      p3_mobile_CONUS_AK_HI_territories_gw_webps
    )
  ),
  
  # Mobile CONUS, AK, HI, major territories background webp config
  tar_target(
    p3_mobile_CONUS_AK_HI_territories_bkgd_webps_config,
    tibble(
      # not date specific
      date = NA,
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "mobile_",
        p0_area_info_df[["name"]],
        "_background_webp"
      ),
      local_image_file = p3_mobile_CONUS_AK_HI_territories_bkgd_webps
    ),
    pattern = map(p0_area_info_df, p3_mobile_CONUS_AK_HI_territories_bkgd_webps)
  ),
  
  # Mobile lower 48 states foreground webp config
  tar_target(
    p3_mobile_lower_48_gw_webps_config,
    tibble(
      date = p1_date_incomplete[["date"]],
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "mobile_",
        p0_states_area_info_df[["name"]],
        "_image_file"
      ),
      local_image_file = p3_mobile_lower_48_gw_webps
    ),
    pattern = map(
      cross(p1_date_incomplete, p0_states_area_info_df),
      p3_mobile_lower_48_gw_webps
    )
  ),
  
  # Mobile lower 48 states background webp config
  tar_target(
    p3_mobile_lower_48_bkgd_webps_config,
    tibble(
      date = NA,
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "mobile_",
        p0_states_area_info_df[["name"]],
        "_background_webp"
      ),
      local_image_file = p3_mobile_lower_48_bkgd_webps
    ),
    pattern = map(p0_states_area_info_df, p3_mobile_lower_48_bkgd_webps)
  ),
  
  ###### Static images ######
  
  # Compress static CONUS_OCONUS pngs with pngquant in-place
  # Requires system installation of pngquant
  # on mac: brew install pngquant
  tar_target(
    p3_static_CONUS_OCONUS_gw_pngs_compressed,
    {
      uncompressed_path <- gsub("\\.png$", "-uncompressed.png",
                                p3_static_CONUS_OCONUS_gw_pngs)
      file.rename(p3_static_CONUS_OCONUS_gw_pngs, uncompressed_path)
      system2(
        "pngquant",
        args = c(
          "--speed", "1",
          "--force",
          "--output", p3_static_CONUS_OCONUS_gw_pngs,
          uncompressed_path
        )
      )
      file.remove(uncompressed_path)
      p3_static_CONUS_OCONUS_gw_pngs
    },
    pattern = map(p3_static_CONUS_OCONUS_gw_pngs),
    format = "file"
  ),
  
  # Static CONUS_OCONUS formatted images config
  tar_target(
    p3_static_CONUS_OCONUS_gw_pngs_config,
    tibble(
      date = p1_date_incomplete[["date"]],
      local_image_type = paste0(
        p0_local_image_type_prefix,
        "desktop_static_",
        p0_desktop_area_name,
        "_image_file"
      ),
      local_image_file = p3_static_CONUS_OCONUS_gw_pngs_compressed
    )
  ),
  
  # Static lower 48 states formatted images config
  # tar_target(
  #   p3_static_lower_48_gw_pngs_config,
  #   tibble(
  #     date = p1_date_incomplete[["date"]],
  #     local_image_type = paste0(
  #       p0_local_image_type_prefix,
  #       "desktop_static_",
  #       p0_states_area_info_df[["name"]],
  #       "_image_file"
  #     ),
  #     local_image_file = p3_static_lower_48_gw_pngs
  #   ),
  #   pattern = map(
  #     cross(p1_date_incomplete, p0_states_area_info_df),
  #     p3_static_lower_48_gw_pngs
  #   )
  # ),

  # full newly generated png config
  tar_target(
    p3_new_gw_images_config,
    bind_rows(p3_desktop_CONUS_OCONUS_gw_webps_config,
              p3_desktop_CONUS_AK_HI_territories_gw_webps_config,
              p3_desktop_lower_48_gw_webps_config,
              p3_mobile_CONUS_AK_HI_territories_gw_webps_config,
              p3_mobile_lower_48_gw_webps_config,
              p3_static_CONUS_OCONUS_gw_pngs_config
              # , p3_static_lower_48_gw_pngs_config
              ) |>
      mutate(
        remote_image_type = str_remove(local_image_type,
                                       p0_local_image_type_prefix),
        remote_image_file_key = gsub(p0_local_image_file_dir,
                                     dirname(p0_remote_image_file_template),
                                     local_image_file),
        newly_generated = TRUE
      )
  ),
  
  # csv with local files to be pushed to s3, with `remote_file_key`
  tar_target(
    p3_new_gw_images_config_csv,
    {
      outfile <- file.path("3_visualize/out", "local_pngs_for_upload.csv")
      readr::write_csv(p3_new_gw_files_config, outfile)
      return(outfile)
    },
    format = "file"
  ),
  
  ##### Generate mp4s for p0_intervals #####
  
  # full png config
  tar_target(
    p3_gw_pngs_config,
    dplyr::bind_rows(p1_downloaded_gw_pngs_config, p3_new_gw_images_config) |>
      dplyr::arrange(date)
  ),
  
  # CONUS_OCONUS mp4 generation for download
  tar_target(
    p3_gw_desktop_mp4,
    build_gw_mp4(
      interval_start_date = p0_interval_start_dates,
      interval_end_date = p0_yesterday_date,
      interval_name = p0_interval_names,
      gw_png_config = p3_gw_pngs_config,
      viz_cfg = p0_viz_config_df,
      img_type_name = paste0(p0_local_image_type_prefix, 
                             p0_video_image_types[[p0_desktop_area_name]]),
      output_template = file.path(p0_local_image_file_dir,
                                  sprintf("gw-movie-desktop-%s-%s.mp4",
                                          p0_desktop_area_name,
                                          p0_interval_names))
      ),
    pattern = map(p0_interval_start_dates, p0_interval_names),
    format = "file"
    ),

  # CONUS_OCONUS mp4 config
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
            dirname(p0_remote_video_file_template),
            local_image_file
          ),
        newly_generated = TRUE
      )
  ),
  
  # Lower 48 states mp4 generation for download
  # tar_target(
  #   p3_gw_states_mp4,
  #   build_gw_mp4(
  #     interval_start_date = p0_interval_start_dates,
  #     interval_end_date = p0_yesterday_date,
  #     interval_name = p0_interval_names,
  #     gw_png_config = p3_gw_pngs_config,
  #     viz_cfg = p0_viz_config_df,
  #     img_type_name = paste0(
  #       "local_desktop_static_",
  #       p0_states_area_info_df[["name"]],
  #       "_image_file"
  #     ),
  #     output_template = file.path(
  #       p0_local_image_file_dir,
  #       sprintf("gw-movie-%s-%s-%s.mp4", "desktop",
  #         p0_states_area_info_df[["name"]],
  #         p0_interval_names
  #       )
  #     )
  #   ),
  #   pattern = cross(
  #     map(p0_interval_start_dates, p0_interval_names),
  #     p0_states_area_info_df
  #   ),
  #   format = "file"
  # ),

  # Lower 48 states mp4 config
  # tar_target(
  #   p3_new_gw_states_mp4_config,
  #   tibble::tibble(
  #     date = p0_yesterday_date,
  #     local_image_type = paste0(
  #       p0_local_image_type_prefix,
  #       "desktop_static_",
  #       p0_states_area_info_df[["name"]],
  #       "_mp4_",
  #       gsub("-", "_", p0_interval_names)
  #     ),
  #     local_image_file = p3_gw_states_mp4
  #   ) |>
  #     dplyr::mutate(
  #       remote_image_type =
  #         stringr::str_remove(local_image_type, p0_local_image_type_prefix),
  #       remote_image_file_key =
  #         gsub(
  #           p0_local_image_file_dir,
  #           dirname(p0_remote_video_file_template),
  #           local_image_file
  #         ),
  #       newly_generated = TRUE
  #     ),
  #   pattern = map(
  #     cross(p0_interval_names, p0_states_area_info_df),
  #     p3_gw_states_mp4
  #   )
  # ),
  
  ##### Generate updated metadata file to be pushed to s3 #####
  tar_target(
    p3_new_gw_files_config,
    dplyr::bind_rows(
      p3_new_gw_images_config,
      p3_new_gw_mp4_config
      # , p3_new_gw_states_mp4_config
    )
  ),
  
  # Get updated version of p1_incomplete w/ remote file keys for new images
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
