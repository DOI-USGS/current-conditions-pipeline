#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("Usage: Rscript check_coverage_shard.R <SHARD_ID>")
}
SHARD_ID <- as.integer(args[[1]])

library(dataRetrieval)
library(lubridate)
library(arrow)
library(tidytable)

dir.create("artifacts", showWarnings = FALSE)

min_years_per_yday <- 21

# ---- Read shard table ----
shard_table <-
  arrow::read_parquet("artifacts/shard_table.parquet") |>
  filter(shard_id == SHARD_ID)

if (nrow(shard_table) == 0) {
  message("No TS IDs in shard ", SHARD_ID)
  arrow::write_parquet(
    tibble(
      time_series_id = character(),
      n_good_days = integer()
    ),
    paste0("artifacts/coverage_", SHARD_ID, ".parquet")
  )
  quit(save = "no")
}

# ---- Pull data ----
pull_one <- function(ts_id, stat_id) {
  if (stat_id == "00003") {
    read_waterdata_daily(
      time_series_id = ts_id,
      skipGeometry = TRUE
    )
  } else {
    # read_waterdata_continuous(
    #   time_series_id = ts_id,
    #   skipGeometry = TRUE
    # )
    tibble(
      time_series_id = character(),
      n_good_days = integer()
    )
  }
}

raw_data <-
  shard_table |>
  split(seq_len(nrow(shard_table))) |>
  lapply(function(row) {
    pull_one(row$time_series_id, row$statistic_id)
  }) |>
  bind_rows()

# ---- Collapse to daily presence ----
daily_presence <-
  raw_data |>
  transmute(
    time_series_id,
    date = as.Date(time)
  ) |>
  distinct()

rm(raw_data)
gc()

# ---- Coverage counting ----
coverage <-
  daily_presence |>
  mutate(
    year = year(date),
    yday = yday(date)
  ) |>
  filter(yday <= 365) |>
  distinct(time_series_id, year, yday)

coverage_summary <-
  coverage |>
  count(time_series_id, yday, name = "n_years") |>
  group_by(time_series_id) |>
  summarise(
    n_good_days = sum(n_years >= min_years_per_yday),
    .groups = "drop"
  )

# ---- Write result ----
arrow::write_parquet(
  coverage_summary,
  paste0("artifacts/coverage_", SHARD_ID, ".parquet")
)
