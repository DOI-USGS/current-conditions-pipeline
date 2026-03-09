#tar_source('1_fetch/src/download_utils.R')
tar_source('1_fetch/src/gw_categorize_daily_vals.R')

p1_targets <- list(
  ##### spatial data #####
  tar_target(
    p1_states_sf,
    tigris::states(cb = TRUE, resolution = "500k")
  ),

  ##### GW data #####
  # Download gw file metadata
  tar_target(
    p1_metadata_csv,
    p0_metadata_path,
    format = "file",
    # ensure target is reran and not skipped for CI
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    p1_metadata,
    readr::read_csv(p1_metadata_csv)
  ),
  # Build out data tibble for all dates
  tar_target(
    p1_date_config,
    {
      date_tibble <- dplyr::tibble(
        date = seq.Date(min(p0_interval_start_dates), p0_yesterday_date, by = 1)
      ) |>
        dplyr::left_join(p1_metadata, by = "date") |>
        # Determine completeness by all image files for a given date documented
        # as existing on s3
        dplyr::mutate(
          complete = if_all(.cols = matches("*_image_file"), .fns = ~ !is.na(.))
        )
    }
  ),
  # Identify dates w/ a complete set of images
  tar_target(
    p1_date_complete,
    dplyr::filter(p1_date_config, complete)
  ),
  # Download all image files for complete dates
  tar_target(
    p1_existing_gw_pngs_config,
    {
      if (nrow(p1_date_complete) == 0) {
        tibble(
          date = p0_yesterday_date,
          remote_image_type = NA_character_,
          remote_image_file_key = NA_character_
        )
      } else {
        p1_date_complete |>
          dplyr::select(-c(parquet_file, complete, matches("(mp4)"))) |>
          tidyr::pivot_longer(
            cols = matches("*_image_file"),
            names_to = "remote_image_type",
            values_to = "remote_image_file_key"
          )
      }
    }
  ),
  tar_target(
    p1_existing_gw_pngs,
    {
      if (!is.na(p1_existing_gw_pngs_config[["remote_image_file_key"]])) {
        download_gw_file(
          filename = p1_existing_gw_pngs_config[["remote_image_file_key"]],
          url_prefix = p0_s3_prod_URL,
          outfile = file.path(
            p0_local_image_file_dir,
            basename(p1_existing_gw_pngs_config[["remote_image_file_key"]])
          )
        )
      } else {
        return(p0_local_image_file_dir)
      }
    },
    pattern = map(p1_existing_gw_pngs_config),
    format = "file"
  ),
  tar_target(
    p1_downloaded_gw_pngs_config,
    {
      if (nrow(p1_date_complete) == 0) {
        tibble(
          date = date(0),
          remote_image_type = character(0),
          remote_image_file_key = character(0),
          local_image_type = character(0),
          local_image_file = character(0),
          newly_generated = logical(0)
        )
      } else {
        p1_existing_gw_pngs_config |>
          dplyr::mutate(
            local_image_type = paste0(
              p0_local_image_type_prefix,
              remote_image_type
            ),
            local_image_file = p1_existing_gw_pngs,
            newly_generated = FALSE
          )
      }
    }
  ),
  # Identify dates w/ an incomplete set of images
  tar_target(
    p1_date_incomplete,
    dplyr::filter(p1_date_config, !complete)
  ),
  # Download parquet files for incomplete dates, in prep for making images
  tar_target(
    p1_gw_parquets,
    gw_categorize_daily_vals(
      fetch_date = p1_date_incomplete$date,
      output_template = p0_local_parquet_file_template,
      end_utc_cutoff = "2015-01-01"
    ),
    pattern = map(p1_date_incomplete),
    format = "file"
  )
)
