gw_categorize_daily_vals <- function(
  parquet_path,
  fetch_date,
  outfile,
  end_utc_cutoff = "2015-01-01"
) {
  gw_ts_ids <- arrow::read_parquet(parquet_path)

  gw_preferred <-
    gw_ts_ids |>
    tidytable::filter(preferred & has_coverage) |>
    # arbitrary end_utc cut-off, just to limit superfluous api.waterdata requests
    tidytable::filter(end_utc >= end_utc_cutoff)

  geometry_table <-
    gw_preferred |>
    tidytable::select(time_series_id, geometry)

  gw_preferred <- gw_preferred |>
    tidytable::select(-geometry)

  # Daily API can handle ~200 site IDs per request
  gw_split_daily <-
    split(
      unique(gw_preferred$time_series_id),
      ceiling(seq_along(unique(gw_preferred$time_series_id)) / 200)
    )

  # Pull yesterday's daily obs
  gw_yesterday <-
    tidytable::map_dfr(
      gw_split_daily,
      ~ {
        dataRetrieval::read_waterdata_daily(
          time_series_id = .x,
          time = fetch_date,
          skipGeometry = TRUE
        )
      }
    ) |>
    # unclear why some rows have missing values?
    tidytable::filter(!is.na(value))

  # Of the sites with an observation yesterday, split them 15 TS ID-chunks
  gw_split_stat <-
    split(
      unique(gw_yesterday$time_series_id),
      ceiling(seq_along(unique(gw_yesterday$time_series_id)) / 15)
    )

  # Month in YY-DD format
  focal_month <-
    format(
      lubridate::floor_date(
        fetch_date,
        unit = "months"
      ),
      "%m-%d"
    )

  # Pull month-of-year stats for GW sites
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
    tidytable::filter(time_of_year_type == "month_of_year") |>
    tidytable::select(
      parent_time_series_id,
      parameter_code,
      percentile,
      value
    ) |>
    tidytable::arrange(parent_time_series_id, value) |>
    tidytable::mutate(
      # flip "water level depth" pcodes to same direction as "elevation above"
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

  # Categorize daily obs relative to month-of-year percentiles
  perc_labels <- c("<5", "5-10", "10-25", "25-75", "75-90", "90-95", ">95")

  gw_categorizations <-
    gw_yesterday |>
    tidytable::mutate(
      # flip "water level depth" pcodes to same direction as "elevation above"
      value = tidytable::case_when(
        parameter_code %in% c("30210", "72019") ~ -1 * value,
        .default = value
      )
    ) |>
    tidytable::left_join(
      gw_monthly_stat,
      by = c("time_series_id" = "parent_time_series_id")
    ) |>
    tidytable::mutate(
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
    tidytable::select(
      time_series_id,
      value,
      category
    )

  gw_out <-
    gw_preferred |>
    tidytable::select(-shard_id) |>
    tidytable::left_join(gw_categorizations, by = "time_series_id") |>
    tidytable::left_join(geometry_table, by = "time_series_id")

  arrow::write_parquet(gw_out, outfile)

  return(outfile)
}
