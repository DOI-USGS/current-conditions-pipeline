# Final updated image metadata file
p4_targets <-
  list(
    tar_target(
      p4_date_config_updated_csv,
      {
        outfile <- file.path("4_update/out", basename(p1_metadata_csv))
        dplyr::bind_rows(
          dplyr::select(p1_date_complete, -complete),
          p3_date_incomplete_updated
        ) |>
          dplyr::arrange(date) |>
          readr::write_csv(outfile)
        return(outfile)
      },
      format = "file"
    ),

    # Dates metadata json
    tar_target(
      p4_date_json,
      {
        outfile <- p0_date_json_path
        named_interval_dates <- set_names(p0_interval_dates, p0_interval_names)
        named_interval_dates <- c(
          named_interval_dates,
          "latest-update" = format(Sys.time(), "%B %d, %Y %I:%M %p")
        )
        jsonlite::write_json(
          named_interval_dates,
          outfile,
          pretty = TRUE,
          auto_unbox = TRUE
        )
        return(outfile)
      },
      format = "file"
    )
  )
