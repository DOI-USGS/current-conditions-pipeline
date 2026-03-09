#tar_source('1_fetch/src/download_utils.R')
tar_source('1_fetch/src/gw_categorize_daily_vals.R')

p1_targets <- list(
  # Download gw file metadata
  tar_target(
    p1_metadata_csv,
    "1_fetch/in/gw_file_metadata.csv",
    format = "file",
    # ensure target is reran and not skipped for CI
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    p1_metadata,
    readr::read_csv(p1_metadata_csv)
  ),
  # Build out data tibble for all dates
  # could use directly to generate p3_gw_pngs
  tar_target(
    p1_date_config,
    {
      date_tibble <- dplyr::tibble(
        date = seq.Date(min(p0_interval_start_dates), p0_yesterday_date, by = 1)
      ) |>
        dplyr::left_join(p1_metadata, by = "date") |>
        dplyr::mutate(
          remote_parquet_file_URL = paste0(p0_s3_prod_URL, parquet_file),
          remote_image_file_URL = paste0(p0_s3_prod_URL, image_file) #,
          # local_parquet_file = ifelse(
          #   file.exists(file.path(p0_parquet_file_dir, basename(parquet_file))),
          #   file.path(p0_parquet_file_dir, basename(parquet_file)),
          #   NA_character_),
          # local_image_file = ifelse(
          #   file.exists(file.path(p0_image_file_dir, basename(image_file))),
          #   file.path(p0_image_file_dir, basename(image_file)),
          #   NA_character_),
        )
    }
  ),
  # or, start filtering
  tar_target(
    p1_date_complete,
    dplyr::filter(p1_date_config, !is.na(p1_date_config[["image_file"]]))
  ),
  # download image files for complete dates (would be file target)
  tar_target(
    p1_existing_gw_pngs,
    download_gw_file(
      metadata_row = p1_date_complete,
      url_col = "remote_image_file_URL",
      output_template = p0_local_image_file_template
    ),
    pattern = map(p1_date_complete),
    format = "file"
  ),
  # When scale up, maybe just check if ALL pngs for given date are on s3
  # if any are missing, regenerate all of them
  tar_target(
    p1_date_incomplete,
    dplyr::filter(p1_date_config, is.na(p1_date_config[["image_file"]]))
  ),
  # download parquet files for incomplete dates (would be file target)
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
