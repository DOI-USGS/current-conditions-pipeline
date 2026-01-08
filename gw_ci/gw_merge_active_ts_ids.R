#!/usr/bin/env Rscript

library(arrow)
library(tidytable)

dir.create("artifacts", showWarnings = FALSE)

files <- list.files(
  "artifacts",
  pattern = "^coverage_.*\\.parquet$",
  full.names = TRUE
)

if (length(files) == 0) {
  stop("No coverage shard artifacts found")
}

coverage_all <-
  map_dfr(files, arrow::read_parquet)

# Sites that pass coverage
gw_active_ts_ids <-
  coverage_all |>
  filter(n_good_days == 365) |>
  distinct(time_series_id)

arrow::write_parquet(
  gw_active_ts_ids,
  "artifacts/gw_active_ts_ids.parquet"
)

message("Wrote ", nrow(gw_active_ts_ids), " active TS IDs")
