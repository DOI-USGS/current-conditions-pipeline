#!/usr/bin/env Rscript

library(lubridate)
library(dataRetrieval)
library(arrow)
library(tidytable)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4) {
  stop("Usage: Rscript gw_initial_pull.R <MIN_YEARS_PER_DAY> <PCODES> <STAT_IDS> <COMP_PERIOD_IDS>")
}

MIN_YEARS_PER_YDAY <- as.integer(args[[1]])
gw_pcodes <- unlist(stringr::str_split(args[[2]], ","))
gw_stat_ids <- unlist(stringr::str_split(args[[3]], ","))
gw_comp_period_ids <- unlist(stringr::str_split(args[[4]], ","))

# 0. Config parameters
focal_date <- Sys.Date() - 1
max_por_start <- focal_date - lubridate::years(MIN_YEARS_PER_YDAY)

# at least one obs. within last window
min_recent_obs <- focal_date - lubridate::days(2)


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

n_parallel_ci_jobs <- 5 # NOTE: this should mach the number of shards defined in the gitlab-ci.yml file

# Split TS IDs into more chunks, which can be run in-parallel for greater efficiency
shard_table <-
  gw_all_ts_ids |>
  mutate(
    por_len = as.numeric(end_utc - begin_utc)
  ) |>
  arrange(monitoring_location_id, desc(por_len)) |>
  # TS IDs in the same shard are submitted sequentially.
  #   This is just a limitation that we can't have too many separate "shards" runniing at the same time
  mutate(
    shard_id = 1:n() %% n_parallel_ci_jobs
  ) |>
  select(
    time_series_id,
    monitoring_location_id,
    parameter_code,
    statistic_id,
    begin_utc,
    end_utc,
    shard_id,
    parent_time_series_id
  )

dir.create("artifacts", showWarnings = FALSE)

arrow::write_parquet(
  shard_table, "artifacts/gw_shard_table.parquet"
)
