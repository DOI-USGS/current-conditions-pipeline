import os
import sys
import time
from pathlib import Path
import pandas as pd
from dataretrieval import waterdata

shard_id = int(sys.argv[1])
min_years_per_yday = int(sys.argv[2])
required_percentiles = set(int(x) for x in sys.argv[3].split(","))

STATS_BATCH_SIZE = 15  # number of TS IDs per /statistics request


def clean_percentiles(df: pd.DataFrame) -> pd.DataFrame:
    """
    Expands nested percentile outputs from observationNormals and returns
    a clean, deduplicated, fully numeric percentile table.

    Output guarantees:
    - One row per (parent_time_series_id, time_of_year, percentile)
    - Percentile column is numeric and complete
    """

    if df.empty:
        return df

    df = df.copy()
    # --- 2. Fill implicit percentiles for min / median / max ---
    percentile_map = {
        "minimum": 0,
        "maximum": 100,
    }

    df["percentile"] = pd.to_numeric(df.get("percentile"), errors="coerce")

    fill_mask = df["percentile"].isna() & df["computation"].isin(percentile_map)
    df.loc[fill_mask, "percentile"] = df.loc[fill_mask, "computation"].map(percentile_map)

    df["percentile"] = df["percentile"].astype("Int64")

    # --- 3. Drop duplicate percentile rows (median commonly duplicated) ---
    df = df.drop_duplicates(subset=["parent_time_series_id", "time_of_year", "percentile"])

    # --- 4. Clean up ordering ---
    df = df.sort_values(["parent_time_series_id", "time_of_year", "percentile"]).reset_index(
        drop=True
    )

    return df


def is_429_error(exc):
    # Common patterns seen from requests / httpx / wrapped HTTP errors
    status = getattr(exc, "status_code", None)
    if status == 429:
        return True

    response = getattr(exc, "response", None)
    if response is not None and getattr(response, "status_code", None) == 429:
        return True

    return False


def get_por_stats_with_retry(
    *,
    parent_time_series_id,
    computation_type,
    max_retries=3,
    base_sleep=1.0,
):
    for attempt in range(1, max_retries + 1):
        try:
            res = waterdata.get_por_stats(
                parent_time_series_id=parent_time_series_id,
                computation_type=computation_type,
            )
            return res[0]

        except Exception as e:
            if not is_429_error(e):
                raise  # fail fast on non-rate-limit errors

            if attempt == max_retries:
                raise

            time.sleep(base_sleep * (2 ** (attempt - 1)))


# Load shard table
shard_table = pd.read_parquet("artifacts/sf_shard_table.parquet")
ts_ids = shard_table.loc[shard_table["shard_id"] == shard_id, "time_series_id"].tolist()


def chunked(seq, size):
    for i in range(0, len(seq), size):
        yield seq[i : i + size]


active_ts_ids = set()

for batch in chunked(ts_ids, STATS_BATCH_SIZE):
    # print(batch)

    raw = get_por_stats_with_retry(
        parent_time_series_id=batch,
        computation_type=["minimum", "maximum", "percentile"],
        max_retries=5,
    )

    if raw.empty:
        continue

    raw = raw.loc[raw["time_of_year_type"] == "day_of_year"]
    tidy = clean_percentiles(raw)
    tidy = tidy.loc[tidy["time_of_year"] != "02-29"]

    for ts_id, g in tidy.groupby("parent_time_series_id"):
        doy_ok = g.groupby("time_of_year")["percentile"].apply(
            lambda x: required_percentiles.issubset(set(x))
        )
        if doy_ok.all():
            active_ts_ids.add(ts_id)

# Merge coverage back onto shard table
shard_result = shard_table.loc[shard_table["shard_id"] == shard_id,].copy()
shard_result["has_coverage"] = shard_result["time_series_id"].isin(active_ts_ids)

# Write full shard with coverage flag
Path("artifacts").mkdir(exist_ok=True)
shard_result.to_parquet(f"artifacts/sf_coverage_{shard_id}.parquet", index=False)
