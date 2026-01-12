#!/usr/bin/env Rscript

library(lubridate)
library(dataRetrieval)
library(arrow)
library(tidytable)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Usage: Rscript gw_initial_pull.R <MIN_YEARS_PER_DAY> <ROLLING_AVERAGE_WINDOW>")
}

MIN_YEARS_PER_YDAY <- as.integer(args[[2]])
ROLLING_AVERAGE_WINDOW <- as.integer(args[[3]])

# 0. Config parameters
focal_date <- Sys.Date() - 1
max_por_start <- focal_date - lubridate::years(MIN_YEARS_PER_YDAY)

# at least one obs. within last window
min_recent_obs <- focal_date - lubridate::days(ROLLING_AVERAGE_WINDOW)

gw_pcodes <- 
  factor(c("72019", "62611", "62610", "72150", "72229",
           "62600", "30210", "62613", "62612", "72231", "72232", "72230", "72227", "72228",
           "72226", "61055", "62601"))
gw_stat_ids <- factor(c("00003", "00011")) # 00003 = mean, 00011 = instant (continuous)
gw_comp_period_ids <- c("Daily", "Points") 
##################################################

# 1. "Naive" data pull, ignorant of data coverage
gw_all_ts_ids <-
  dataRetrieval::read_waterdata_ts_meta(
  parameter_code = gw_pcodes, 
  statistic_id = gw_stat_ids, 
  computation_period_identifier = gw_comp_period_ids, 
  begin = paste0("1700-01-01/",max_por_start),
  end = paste0(min_recent_obs,"/.."),
  skipGeometry = TRUE
) |>
  tidytable::as_tidytable()

# Select *one* timeseries ID per monitoring location, based on an opinionated prioritization
gw_filt_ts_ids <-
  gw_all_ts_ids |>
  # rank stat IDs and pcodes based on "preference".
  # E.g., prefer 00003 if available over 00011. Prefer 72019 if available, then 62611, then...
  mutate(
    stat_rank = match(statistic_id, gw_stat_ids),
    pcode_rank = match(parameter_code, gw_pcodes),
    por_len = as.numeric(end_utc - begin_utc)
  ) |>
  # order of prioritization: stat ID, longest POR, most recent end date, pcode
  arrange(
    monitoring_location_id,
    stat_rank,
    desc(por_len),
    desc(end_utc),
    pcode_rank
  ) |>
  group_by(monitoring_location_id) |>
  slice(1) |>
  ungroup() |>
  select(-c(stat_rank, pcode_rank)) |>
  mutate(begin_utc = as.Date(begin_utc), end_utc = as.Date(end_utc))

ideal_rows_per_shard <- 50000
n_parallel_ci_jobs <- 10 # NOTE: this should mach the number of shards defined in the gitlab-ci.yml file

# Split TS IDs into more chunks, which can be run in-parallel for greater efficiency
shard_table <-
  gw_filt_ts_ids |>
  filter(statistic_id %in% c("00003")) |>#, "00011")) |>
  select(time_series_id, statistic_id, begin_utc, end_utc, por_len) |>
  mutate(
    est_rows = ifelse(
      statistic_id == "00003",
      por_len, # daily = one obs. per day
      por_len * 4 * 24 # continuous (obs. every 15 minutes) = 96 obs. per day
    )
  ) |>
  # group_by(statistic_id) |>
  arrange(est_rows) |>
  # TS IDs in the same "group" are submitted in the same request. 
  #   The goal is to max out the 50,000 row/request limit without going over (e.g., a 50,001 row would still require 2 requests)
  # Groups in the same shard are submitted sequentially.
  #   This is just a limitation that we can't have too many separate "shards" runniing at the same time
  mutate(
    group_id = ((cumsum(est_rows) - 1) %/% ideal_rows_per_shard),
    shard_id = group_id %% n_parallel_ci_jobs
  ) |>
  select(time_series_id, statistic_id, begin_utc, end_utc, group_id, shard_id)

dir.create("artifacts", showWarnings = FALSE)

arrow::write_parquet(
  shard_table, "artifacts/gw_shard_table.parquet"
)
