#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3) {
  stop("Usage: Rscript gw_coverage_per_shard.R <SHARD_ID> <MIN_YEARS_PER_DAY> <PERCENTILES>")
}
SHARD_ID <- as.integer(args[[1]])
MIN_YEARS_PER_YDAY <- as.integer(args[[2]])
required_percentiles <- unlist(stringr::str_split(args[[3]], ","))

STATS_BATCH_SIZE = 15 # number of TS IDs per /statistics request

library(dataRetrieval)
library(lubridate)
library(arrow)
library(tidytable)

dir.create("artifacts", showWarnings = FALSE)

# ---- Read shard table ----
shard_table <-
  arrow::read_parquet("artifacts/gw_shard_table.parquet") |>
  filter(shard_id == SHARD_ID)

if (nrow(shard_table) == 0) {
  message("No TS IDs in shard ", SHARD_ID)
  arrow::write_parquet(
    tidytable::tidytable(
      time_series_id = character(),
      n_good_days = integer()
    ),
    paste0("artifacts/coverage_", SHARD_ID, ".parquet")
  )
  quit(save = "no")
}

gw_ts_id_split <-
    split(
    unique(shard_table$time_series_id),
    ceiling(
      seq_along(unique(shard_table$time_series_id)) /
        STATS_BATCH_SIZE
    )
  )

# # Note: run in-parallel locally:
# library(future)
# library(furrr)
# library(parallelly)
# future::plan(future::multisession,
#                workers = ceiling(parallel::detectCores() / 3))

gw_monthly_stats <-
  # # Note: run in-parallel locally:
  # furrr::future_map_dfr(
  tidytable::map_dfr(
    gw_ts_id_split, function(ids) {
    retry::retry(
      dataRetrieval::read_waterdata_stats_por(
      parent_time_series_id = ids,
      computation = c("minimum", "maximum", "percentile")
    ) |>
      filter(time_of_year_type == "month_of_year"),
      when = "429", max_tries = Inf
    )
  })

# Filter to TS IDs with full set of percentiles for all 12 months 
gw_complete_percs <-
  gw_monthly_stats |>
  filter(!is.na(value)) |>
  group_by(parent_time_series_id, monitoring_location_id, parameter_code) |>
  tally() |>
  ungroup() |>
  filter(n == 12 * length(required_percentiles)) |>
  distinct(parent_time_series_id) |>
  mutate(has_coverage = TRUE)

# Join this table back to TS ID metadata
coverage_summary <-
  shard_table |>
  left_join(
    gw_complete_percs,
    by = c("time_series_id" = "parent_time_series_id")
  )

message(paste0(
  unique(coverage_summary$monitoring_location_id[
    coverage_summary$has_coverage
  ]),
  " sites with full month-of-year percentiles in shard ",
  SHARD_ID
))

# ---- Write result ----
arrow::write_parquet(
  coverage_summary,
  paste0("artifacts/gw_coverage_", SHARD_ID, ".parquet")
)
