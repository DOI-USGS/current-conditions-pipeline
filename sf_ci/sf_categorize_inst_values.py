from dataretrieval import waterdata as wd
import pandas as pd
import numpy as np
from datetime import date
from itertools import islice


def chunked(iterable, size):
    it = iter(iterable)
    while True:
        chunk = list(islice(it, size))
        if not chunk:
            break
        yield chunk


sf_ts_ids = pd.read_parquet("artifacts/sf_coverage.parquet")

sf_preferred = sf_ts_ids[
    sf_ts_ids["has_coverage"] & sf_ts_ids["preferred"] & sf_ts_ids["parent_time_series_id"].notna()
]

sf_preferred = sf_preferred[sf_preferred["end_utc"] >= "2015-01-01"]

inst_ts_ids = sf_preferred["parent_time_series_id"].tolist()

dfs = []

for batch in chunked(inst_ts_ids, 100):
    df, _ = wd.get_continuous(time_series_id=batch, time="PT24H")
    if df is not None and not df.empty:
        dfs.append(df)

# Recombine
sf_continuous = pd.concat(dfs, ignore_index=True)

sf_last_24h_ave = sf_continuous.groupby("time_series_id", as_index=False).agg(
    average_value=("value", "mean")
)

sf_daily_ts = sf_preferred[
    sf_preferred["parent_time_series_id"].isin(sf_last_24h_ave["time_series_id"])
]["time_series_id"]

dfs = []
today_str = date.today().strftime("%m-%d")

for batch in chunked(sf_daily_ts, 15):
    df, _ = wd.get_por_stats(
        parent_time_series_id=batch,
        start_date=today_str,
        end_date=today_str,
        expand_percentiles=True,
        computation_type=["minimum", "percentile"],
    )
    if df is not None and not df.empty:
        dfs.append(df)

sf_stats = pd.concat(dfs, ignore_index=True)
sf_stats = sf_stats[sf_stats["time_of_year_type"] == "day_of_year"]
sf_stats = sf_stats[sf_stats["computation"] == "percentile"]

sf_stats["value"] = pd.to_numeric(sf_stats["value"])
sf_stats["percentile"] = sf_stats["percentile"].astype(int).astype(str).apply(lambda x: f"p{x}")

sf_stats_wide = (
    sf_stats[["parent_time_series_id", "percentile", "value"]]
    .drop_duplicates()
    .pivot(index="parent_time_series_id", columns="percentile", values="value")
    .reset_index()
)

# NOTE: this merge isn't working because sf_continuous has continuous TS IDs while sf_stats_wide has daily TS IDs.
# Need to bridge the two together using sf_preferred as a cross-walk
sf_joined = sf_continuous.merge(
    sf_stats_wide, left_on="time_series_id", right_on="parent_time_series_id", how="left"
)

# Define the bins in order
conditions = [
    sf_joined["value"] < sf_joined["p5"],
    sf_joined["value"] <= sf_joined["p10"],
    sf_joined["value"] <= sf_joined["p25"],
    sf_joined["value"] <= sf_joined["p75"],
    sf_joined["value"] <= sf_joined["p90"],
    sf_joined["value"] <= sf_joined["p95"],
    sf_joined["value"] > sf_joined["p95"],
]

labels = ["<5", "5–10", "10–25", "25–75", "75–90", "90–95", ">95"]

sf_joined["category"] = np.select(conditions, labels, default="NA")

sf_joined
