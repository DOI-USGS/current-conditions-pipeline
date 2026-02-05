library(dataRetrieval)
library(arrow)
library(sf)
library(tidytable)

gw_ts_ids <- arrow::read_parquet("artifacts/gw_coverage.parquet")

gw_preferred <-
  gw_ts_ids |>
  filter(preferred & has_coverage) |>
  # arbitrary end_utc cut-off, just to limit superfluous api.waterdata requests
  filter(end_utc >= "2015-01-01")

gw_split_daily <-
  split(
    unique(gw_preferred$time_series_id),
    ceiling(seq_along(unique(gw_preferred$time_series_id)) / 200)
  )


gw_yesterday <-
  tidytable::map_dfr(
    gw_split_daily,
    ~ {
      read_waterdata_daily(
        time_series_id = .x,
        time = Sys.Date() - lubridate::days(1),
        skipGeometry = TRUE
      )
    }
  ) |>
  filter(!is.na(value))

gw_split_stat <-
  split(
    unique(gw_yesterday$time_series_id),
    ceiling(seq_along(unique(gw_yesterday$time_series_id)) / 15)
  )

focal_month <-
  format(
    lubridate::floor_date(
      Sys.Date() - lubridate::days(2),
      unit = "months"
    ),
    "%m-%d"
  )

gw_monthly_stat <-
  tidytable::map_dfr(
    gw_split_stat,
    ~ {
      retry::retry(
        dataRetrieval::read_waterdata_stats_por(
          parent_time_series_id = .x,
          start_date = focal_month,
          end_date = focal_month,
          computation = c("minimum", "maximum", "percentile")
        ),
        when = "429|500",
        max_tries = 10
      )
    }
  ) |>
  sf::st_drop_geometry() |>
  filter(time_of_year_type == "month_of_year") |>
  select(parent_time_series_id, parameter_code, percentile, value) |>
  arrange(parent_time_series_id, value) |>
  mutate(
    # flip "water level depth" pcodes to same direction as "elevation"
    value = tidytable::case_when(
      parameter_code %in% c("30210", "72019") ~ -1 * value,
      .default = value
    )
  ) |>
  tidytable::pivot_wider(
    names_from = "percentile",
    values_from = "value",
    id_cols = c("parent_time_series_id"),
    names_prefix = "p_"
  )

perc_labels <- c("<5", "5-10", "10-25", "25-75", "75-90", "90-95", ">95")

gw_categorizations <-
  gw_yesterday |>
  mutate(
    time_of_year = lubridate::floor_date(time, unit = "months"),
    value = case_when(
      parameter_code %in% c("30210", "72019") ~ -1 * value,
      .default = value
    )
  ) |>
  left_join(
    gw_monthly_stat,
    by = c("time_series_id" = "parent_time_series_id")
  ) |>
  mutate(
    category = factor(
      data.table::fcase(
        value < p_5   , "<5"    ,
        value <= p_10 , "5-10"  ,
        value <= p_25 , "10-25" ,
        value <= p_75 , "25-75" ,
        value <= p_90 , "75-90" ,
        value <= p_95 , "90-95" ,
        value > p_95  , ">95"
      ),
      levels = perc_labels
    )
  ) |>
  select(
    monitoring_location_id,
    parameter_code,
    statistic_id,
    time,
    value,
    category,
    unit_of_measure,
    time_series_id
  )

arrow::write_parquet(gw_categorizations, paste0("artifacts/gw_categorizations_",Sys.Date() - lubridate::days(1),".parquet"))
