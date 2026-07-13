import os
import sys
import time
import random
from pathlib import Path
import pandas as pd
from requests.exceptions import JSONDecodeError
from dataretrieval import waterdata
import pyarrow as pa
import pyarrow.parquet as pq

shard_id = int(sys.argv[1])
min_years_per_yday = int(sys.argv[2])
required_percentiles = set(int(x) for x in sys.argv[3].split(","))

STATS_BATCH_SIZE = 10  # number of TS IDs per /statistics request


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
    df["value"] = pd.to_numeric(df["value"], errors="coerce")

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

    # check if 429 is wrapped in a generic message
    msg = str(exc).lower()
    if "429" in msg or "too many requests" in msg:
        return True

    return False


def is_retryable_error(exc):
    # Explicit 429
    if is_429_error(exc):
        return True

    # Non-JSON gateway response
    if isinstance(exc, JSONDecodeError):
        return True

    # dataretrieval wraps these as generic Exceptions
    msg = str(exc).lower()
    if "expecting value" in msg or "json" in msg:
        return True

    return False


def get_stats_por_with_retry(
    *,
    parent_time_series_id,
    computation_type,
    max_retries=3,
    base_sleep=1.0,
):
    for attempt in range(1, max_retries + 1):
        try:
            res = waterdata.get_stats_por(
                parent_time_series_id=parent_time_series_id,
                computation_type=computation_type,
            )
            return res[0]

        except Exception as e:
            # log response on an exception
            if hasattr(e, "response"):
                print("RAW RESPONSE:", e.response.text[:200])
            if not is_429_error(e):
                raise  # fail fast on non-rate-limit errors
            if not is_retryable_error(e):
                raise
            if attempt == max_retries:
                raise

            sleep = max(1.0, base_sleep * (2 ** (attempt - 1)) * random.uniform(0.7, 1.3))
            time.sleep(sleep)


# Load shard table
shard_table = pd.read_parquet("artifacts/sf_shard_table.parquet")
ts_ids = shard_table.loc[shard_table["shard_id"] == shard_id, "time_series_id"].tolist()


def chunked(seq, size):
    for i in range(0, len(seq), size):
        yield seq[i : i + size]


active_ts_ids = set()
writers = {}  # mm_dd -> ParquetWriter

batches = chunked(ts_ids, STATS_BATCH_SIZE)

MAX_CONSECUTIVE_FAILURES = 3
LONG_PAUSE_SECONDS = 60

consecutive_failures = 0

for batch in batches:#[batch_start + 1:]:
    print(batch)

    try:
        raw = get_stats_por_with_retry(
            parent_time_series_id=batch,
            computation_type=["minimum", "maximum", "percentile"],
            max_retries=5,
        )
        consecutive_failures = 0  # reset on success

    except Exception as e:
        consecutive_failures += 1
        print(f"Batch failed ({consecutive_failures} consecutive): {e}")

        if consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
            print(f"Too many consecutive failures — pausing {LONG_PAUSE_SECONDS}s")
            time.sleep(LONG_PAUSE_SECONDS)
            consecutive_failures = 0  # reset after pause; give the API a fresh chance
        continue  # skip processing this batch and move on

    time.sleep(0.5)

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

        # --- Incremental write, one file per MM-DD ---
    for mm_dd, group in tidy.groupby("time_of_year"):
        table = pa.Table.from_pandas(group.drop(columns = "geometry", errors = "ignore"), preserve_index=False)
        if mm_dd not in writers:
            out_path = f"artifacts/sf_percentiles/sf_percentiles_{shard_id}_{mm_dd}.parquet"
            writers[mm_dd] = pq.ParquetWriter(out_path, table.schema)
        writers[mm_dd].write_table(table)

for writer in writers.values():
    writer.close()

# Merge coverage back onto shard table
shard_result = shard_table.loc[shard_table["shard_id"] == shard_id,].copy()
shard_result["has_coverage"] = shard_result["time_series_id"].isin(active_ts_ids)

# Write full shard with coverage flag
Path("artifacts").mkdir(exist_ok=True)
shard_result.to_parquet(f"artifacts/sf_coverage_{shard_id}.parquet", index=False)
