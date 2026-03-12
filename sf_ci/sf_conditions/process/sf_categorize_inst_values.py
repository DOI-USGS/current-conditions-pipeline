from dataretrieval import waterdata as wd
import pandas as pd
import numpy as np
from datetime import date, datetime
from itertools import islice
from sf_conditions.fetch.get_s3 import download_file_urllib

def chunked(iterable, size):
    it = iter(iterable)
    while True:
        chunk = list(islice(it, size))
        if not chunk:
            break
        yield chunk

def categorize_sf(date_of_interest, coverage_parquet, s3_url_file, parquet_file):
    if s3_url_file != 'NA':
        print ("downloading... " + s3_url_prefix + s3_url_file)
        download_file_urllib(s3_url_prefix + s3_url_file, folder)
    else:
        print ("generating... " + parquet_file)
        sf_ts_ids = pd.read_parquet(coverage_parquet)

        # We want to pull TS IDs that have a full set of percentiles *and* a continuous TS ID
        sf_preferred = sf_ts_ids[
            sf_ts_ids["has_coverage"] & sf_ts_ids["preferred"] & sf_ts_ids["parent_time_series_id"].notna()
        ]

        # Arbitrary end_utc cutoff to reduce unnecessary continuous requests
        sf_preferred = sf_preferred[sf_preferred["end_utc"] >= "2015-01-01"]
        sf_preferred = sf_preferred.rename(
            columns={"time_series_id": "daily_ts_id", "parent_time_series_id": "inst_ts_id"}
        )

        # Fetch continuous data from last X hours (e.g., X = 24)
        inst_ts_ids = sf_preferred["inst_ts_id"].tolist()
        dfs = []
        for batch in chunked(inst_ts_ids, 100):
            if date_of_interest == date.today():
                timemark = "PT24H"
            else:
                timemark = date_of_interest + "T00:00:00Z/" + date_of_interest + "T23:59:59Z"
                
            df, _ = wd.get_continuous(time_series_id=batch, time=timemark)

            if df is not None and not df.empty:
                dfs.append(df)

        sf_continuous = pd.concat(dfs, ignore_index=True)
        sf_continuous = sf_continuous.dropna(subset="value")

        # Aggregate last X hours of data to a single average
        sf_ave = sf_continuous.groupby("time_series_id", as_index=False).agg(
            average_value=("value", "mean")
        )

        # For sites with continuous data, pull their percentiles
        sf_daily_ts = sf_preferred[sf_preferred["inst_ts_id"].isin(sf_ave["time_series_id"])]["daily_ts_id"]
        dfs = []
        today_str = date_of_interest[5:]
        for batch in chunked(sf_daily_ts, 15):
            df, _ = wd.get_stats_por(
                parent_time_series_id=batch,
                start_date=today_str,
                end_date=today_str,
                expand_percentiles=True,
                # Function throws an error if computation_type = 'percentile' only?
                computation_type=["minimum", "maximum", "percentile"],
            )
            if df is not None and not df.empty:
                dfs.append(df)

        sf_stats = pd.concat(dfs, ignore_index=True)
        sf_stats = sf_stats[sf_stats["time_of_year_type"] == "day_of_year"]
        sf_stats.loc[sf_stats["computation"] == "minimum", "percentile"] = 0
        sf_stats.loc[sf_stats["computation"] == "maximum", "percentile"] = 100

        # Next, we need to join the average values to the percentile
        sf_stats["value"] = pd.to_numeric(sf_stats["value"])
        sf_stats["percentile"] = sf_stats["percentile"].astype(int).astype(str).apply(lambda x: f"p{x}")

        # Spread percentile df to one row per TS ID
        sf_stats_wide = (
            sf_stats[["parent_time_series_id", "percentile", "value"]]
            .drop_duplicates()
            .pivot(index="parent_time_series_id", columns="percentile", values="value")
            .reset_index()
        )

        # Join average values to percentiles --
        # Need to use sf_preferred as the cross-walk between continuous and daily TS IDs
        sf_joined = (
            sf_ave.merge(
                sf_preferred[["daily_ts_id", "inst_ts_id"]],
                left_on="time_series_id",
                right_on="inst_ts_id",
                how="left",
            ).merge(sf_stats_wide, left_on="daily_ts_id", right_on="parent_time_series_id", how="left")
        )[
            [
                "daily_ts_id",
                "inst_ts_id",
                "average_value",
                "p0",
                "p5",
                "p10",
                "p25",
                "p75",
                "p90",
                "p95",
                "p100",
            ]
        ]

        # Define the bins in order
        conditions = [
            sf_joined["average_value"] < sf_joined["p0"],
            sf_joined["average_value"] <= sf_joined["p5"],
            sf_joined["average_value"] <= sf_joined["p10"],
            sf_joined["average_value"] <= sf_joined["p25"],
            sf_joined["average_value"] <= sf_joined["p75"],
            sf_joined["average_value"] <= sf_joined["p90"],
            sf_joined["average_value"] <= sf_joined["p95"],
            sf_joined["average_value"] <= sf_joined["p100"],
            sf_joined["average_value"] > sf_joined["p100"],
        ]

        labels = ["<0", "0-5", "5-10", "10-25", "25-75", "75-90", "90-95", "95-100", ">100"]

        sf_joined["category"] = np.select(conditions, labels, default="NA")
        sf_joined = sf_joined[["daily_ts_id", "inst_ts_id", "average_value", "category"]]

        # Add categorizations to full sf_preferred df
        # TS IDs missing recent inst data rows will have NaN categorizations, but we still want to visualuze them
        sf_out = sf_preferred.drop(columns="shard_id").merge(
            sf_joined, on=["daily_ts_id", "inst_ts_id"], how="left"
        )
        sf_out["runtime"] = date_of_interest

        # Name outfile after hour the pipeline ran
        # runtime = datetime.now().replace(minute=0, second=0, microsecond=0).strftime("%Y-%m-%d-%Hh")

        sf_out.to_parquet(path=parquet_file)

if __name__ == "__main__":
    s3_url_prefix = snakemake.params["s3_url_prefix"]
    s3_url_file = snakemake.params["s3_url_file"]
    folder = snakemake.params["folder"]
    coverage_parquet = snakemake.input["coverage_parquet"]
    parquet_file = snakemake.output["parquet_file"]

    # default file naming convention
    file_prefix = "data/sf_categorizations_"
    file_suffix = ".parquet"

    date_of_interest = parquet_file[len(file_prefix):-len(file_suffix)]
  
    categorize_sf(date_of_interest, coverage_parquet, s3_url_file, parquet_file)