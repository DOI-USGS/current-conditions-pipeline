#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3) {
  stop("Usage: Rscript gw_coverage_per_shard.R <SHARD_ID> <MIN_YEARS_PER_DAY> <ROLLING_AVERAGE_WINDOW>")
}
SHARD_ID <- as.integer(args[[1]])
MIN_YEARS_PER_YDAY <- as.integer(args[[2]])
ROLLING_AVERAGE_WINDOW <- as.integer(args[[3]])

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

# ---- Pull data ----
raw_data <-
  shard_table |>
  group_by(group_id) |>
  group_split() |>
  map_dfr(function(dat) {
    if(unique(dat$statistic_id) == "00003"){
      read_waterdata_daily(
        time_series_id = dat$time_series_id,
        skipGeometry = TRUE,
        limit = 50000
      )
    } else{
      # read_waterdata_continuous(
      #   time_series_id = dat$time_series_id,
      #   skipGeometry = TRUE,
      #   limit = 50000
      # )
      NULL
    }
  }) |>
  mutate(time = as.Date(time)) |>
  distinct(time_series_id, statistic_id, time)

if(nrow(raw_data) == 0){
  arrow::write_parquet(
    data.frame(
      time_series_id = character(0),
      statistic_id = character(0),
      has_coverage = logical(0)
    ),
    paste0("artifacts/coverage_", SHARD_ID, ".parquet")
  )
  
  quit(save = "no")
}

message("Computing missing days")

# Determine ydays with <(20) years of complete data
missing_doy <-
  raw_data |>
  distinct(time_series_id, time) |>
  arrange(time_series_id, time) |>
  mutate(yday = lubridate::yday(time)) |>
  group_by(time_series_id, yday) |>
  tally(name = "n_years") |>
  filter(n_years < MIN_YEARS_PER_YDAY)

# duplicate yday to wrap around a new year (in case there >(30) day periods that span 2 calendar years)
missing_doy_circular <- missing_doy |>
  mutate(yday2 = yday + 365) |>
  bind_rows(
    missing_doy |>
      mutate(yday2 = yday)
  )

# compute the number of consecutive days with <(20) years of data
missing_runs <- missing_doy_circular |>
  arrange(time_series_id, yday2) |>
  group_by(time_series_id) |>
  mutate(
    run_id = cumsum(c(1, diff(yday2) != 1))
  ) |>
  group_by(time_series_id, run_id) |>
  summarise(
    run_length = n(),
    .groups = "drop"
  )

# if there's a run of at least (30) consecutive days with <(20) years of data,
# then we couldn't compute the percentiles needed
invalid_ts_ids <-
  missing_runs |>
  filter(run_length >= ROLLING_AVERAGE_WINDOW) |>
  distinct(time_series_id)

# gw_active_ts_ids <-
#   setdiff(unique(raw_data$time_series_id), invalid_ts_ids$time_series_id)
coverage_summary <-
  raw_data |>
  distinct(time_series_id, statistic_id) |>
  mutate(has_coverage = !(time_series_id %in% invalid_ts_ids$time_series_id))

# ---- Write result ----
arrow::write_parquet(
  coverage_summary,
  paste0("artifacts/gw_coverage_", SHARD_ID, ".parquet")
)
