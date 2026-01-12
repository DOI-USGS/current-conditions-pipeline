import os
import sys
from pathlib import Path
import pandas as pd
from dataretrieval import waterdata

shard_id = int(sys.argv[1])
min_years_per_yday = int(sys.argv[2])
required_percentiles = set(int(x) for x in sys.argv[3].split(","))

STATS_BATCH_SIZE = 10 # number of TS IDs per /statistics request

def clean_percentiles(df: pd.DataFrame) -> pd.DataFrame:
    """
    Expands nested percentile outputs from observationNormals and returns
    a clean, deduplicated, fully numeric percentile table.

    Output guarantees:
    - One row per (parent_time_series_id, time_of_year, percentile)
    - Percentile column is numeric and complete
    - Median duplication removed
    """

    if df.empty:
        return df

    df = df.copy()
    # --- 2. Fill implicit percentiles for min / median / max ---
    percentile_map = {
        "minimum": 0,
        "median": 50,
        "maximum": 100,
    }

    df["percentile"] = pd.to_numeric(df.get("percentile"), errors="coerce")

    fill_mask = df["percentile"].isna() & df["computation"].isin(percentile_map)
    df.loc[fill_mask, "percentile"] = (
        df.loc[fill_mask, "computation"].map(percentile_map)
    )

    df["percentile"] = df["percentile"].astype("Int64")

    # --- 3. Drop duplicate percentile rows (median commonly duplicated) ---
    df = df.drop_duplicates(
        subset=["parent_time_series_id", "time_of_year", "percentile"]
    )

    # --- 4. Clean up ordering ---
    df = df.sort_values(
        ["parent_time_series_id", "time_of_year", "percentile"]
    ).reset_index(drop=True)

    return df


# Load shard table
shard_table = pd.read_parquet("artifacts/sf_shard_table.parquet")
ts_ids = shard_table.loc[
    shard_table["shard_id"] == shard_id, "time_series_id"
].tolist()

def chunked(seq, size):
    for i in range(0, len(seq), size):
        yield seq[i:i + size]

active_ts_ids = set()

for batch in chunked(ts_ids, STATS_BATCH_SIZE):
    raw = waterdata.get_por_stats(
        parent_time_series_id=batch,
        computation_type=["minimum", "median", "maximum", "percentile"],
    )[0]

    if raw.empty:
        continue

    raw = raw.loc[raw["time_of_year_type"] == "day_of_year"]
    tidy = clean_percentiles(raw)
    tidy = tidy.loc[tidy["time_of_year"] != "02-29"]  # drop Feb 29

    # Check coverage per TS ID
    for ts_id, g in tidy.groupby("parent_time_series_id"):
        doy_ok = g.groupby("time_of_year")["percentile"].apply(
            lambda x: required_percentiles.issubset(set(x))
        )
        if doy_ok.all():
            active_ts_ids.add(ts_id)

# Merge coverage back onto shard table
shard_result = shard_table.loc[shard_table["shard_id"] == shard_id, ["time_series_id", "statistic_id"]].copy()
shard_result["has_coverage"] = shard_result["time_series_id"].isin(active_ts_ids)

# Write full shard with coverage flag
Path("artifacts").mkdir(exist_ok=True)
shard_result.to_parquet(f"artifacts/sf_coverage_{shard_id}.parquet", index=False)
