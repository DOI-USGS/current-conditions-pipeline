#!/usr/bin/env Rscript

library(arrow)
library(tidytable)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Usage: Rscript gw_coverage_per_shard.R <PCODES> <STAT_IDS>")
}
gw_pcodes <- unlist(stringr::str_split(args[[1]], ","))
gw_stat_ids <- unlist(stringr::str_split(args[[2]], ","))

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
# But keep the non-preferred TS IDs in case there's missing data in the future
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
