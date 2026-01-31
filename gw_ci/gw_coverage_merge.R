#!/usr/bin/env Rscript

library(arrow)
library(tidytable)

gw_pcodes <- unlist(stringr::str_split(args[[3]], ","))
gw_stat_ids <- unlist(stringr::str_split(args[[4]], ","))

dir.create("artifacts", showWarnings = FALSE)

files <- list.files(
  "artifacts",
  pattern = "^gw_coverage_.*\\.parquet$",
  full.names = TRUE
)

if (length(files) == 0) {
  stop("No coverage shard artifacts found")
}

# Indicate a "preferred" TS ID per monitoring location based on opinionated ranking
gw_active_ts_ids <-
  map_dfr(files, arrow::read_parquet) |>
  arrange(
    monitoring_location_id,
    has_coverage,
    factor(statistic_id, levels = gw_stat_ids),
    desc(end_utc - begin_utc),
    desc(end_utc),
    factor(parameter_code, levels = gw_pcodes)
  ) |>
  group_by(monitoring_location_id) |>
  mutate(preferred = c(TRUE, rep(FALSE, n() - 1))) |>
  ungroup()

arrow::write_parquet(
  gw_active_ts_ids,
  "artifacts/gw_coverage.parquet"
)

message("Wrote ", nrow(gw_active_ts_ids), " active TS IDs")
