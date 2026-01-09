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

min_years_per_yday <- 20

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
raw_data <-
  shard_table |>
  group_by(group_id) |>
  group_split() |>
  map_dfr(function(dat) {
    if(dat$statistic_id == "00003"){
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
  distinct(time_series_id, time)

message("Computing missing days")

missing_ydays <-
  raw_data |>
  group_by(time_series_id) |>
  mutate(time_lag = lag(time), time_diff = as.numeric(time - time_lag)) |>
  ungroup() |>
  # we care about time series IDs where there's a gap >30 days
  filter(time_diff > 30) |>
  # next, compute which date(s) are impacted by the >30 day gap
  mutate(
    missing_window_start = lubridate::yday(time_lag + lubridate::days(31)),
    missing_window_end = lubridate::yday(time - lubridate::days(1))
  ) |>
  select(time_series_id, missing_window_start, missing_window_end) |>
  # We care about which day of the year the missing stretches of data affect
  pmap_dfr(
    ~ {
      (if (..2 > ..3) {
        tidytable::tidytable(
          yday = c(seq(..2, 366, by = 1), seq(1, ..3, by = 1))
        )
      } else {
        tidytable::tidytable(yday = seq(..2, ..3, by = 1))
      }) |>
        mutate(time_series_id = ..1) |>
        arrange(yday)
    }
  ) |>
  group_by(time_series_id, yday) |>
  tally(name = "n_missing") |>
  ungroup() |>
  mutate(yday = as.numeric(yday))

# Next, determine whether each TS ID has enough data, correcting for
# any missingness
por_obs_corrected <-
  shard_table |>
  select(time_series_id, begin_utc, end_utc) |>
  pmap_dfr(
    ~ {
      table(lubridate::yday(seq.Date(..2, ..3, by = "day"))) |>
        tidytable::as_tidytable() |>
        rename(
          yday = V1,
          n_obs = N
        ) |>
        mutate(
          time_series_id = ..1,
          yday = as.numeric(yday)
        )
    }
  ) |>
  left_join(
    missing_ydays,
    by = c("yday", "time_series_id")
  ) |>
  tidytable::replace_na(replace = list(n_missing = 0)) |>
  mutate(total_obs = n_obs - n_missing) |>
  group_by(time_series_id) |>
  # count number of ydays that have at least (20) years of data
  summarize(n_good_days = sum(total_obs >= min_years_per_yday))

# ---- Write result ----
arrow::write_parquet(
  coverage_summary,
  paste0("artifacts/coverage_", SHARD_ID, ".parquet")
)
