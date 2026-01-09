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

gw_active_ts_ids <-
  map_dfr(files, arrow::read_parquet) |>
  filter(has_coverage)

arrow::write_parquet(
  gw_active_ts_ids,
  "artifacts/gw_active_ts_ids.parquet"
)

message("Wrote ", nrow(gw_active_ts_ids), " active TS IDs")
