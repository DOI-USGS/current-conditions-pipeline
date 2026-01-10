import sys
from pathlib import Path
import pandas as pd
from dataretrieval import waterdata
from sf_ci.sf_clean_percentiles import clean_percentiles

REQUIRED_PERCENTILES = {0, 10, 25, 50, 75, 90, 100}
STATS_BATCH_SIZE = 10

shard_id = int(sys.argv[1])
# shard_id = 1

# Load shard table
shard_table = pd.read_parquet("artifacts/sf_shard_table.parquet")
ts_ids = shard_table.loc[
    shard_table["shard_id"] == shard_id, "time_series_id"
].tolist()

def chunked(seq, size):
    for i in range(0, len(seq), size):
        yield seq[i:i + size]

active_ts_ids = []

for batch in chunked(ts_ids, STATS_BATCH_SIZE):
    print(batch)
    # try:
    raw = waterdata.get_por_stats(
        parent_time_series_id=batch,
        computation_type=["minimum", "median", "maximum", "percentile"],
    )[0]
    # except Exception:
    #     continue

    if raw.empty:
        continue

    raw = raw.loc[raw["time_of_year_type"] == "day_of_year"]

    tidy = clean_percentiles(raw)

    # Drop Feb 29 globally
    tidy = tidy.loc[tidy["time_of_year"] != "02-29"]

    # ---- PER–TIME-SERIES COVERAGE CHECK ----
    for ts_id, g in tidy.groupby("parent_time_series_id"):

        # For each day-of-year, check full percentile set
        doy_ok = (
            g.groupby("time_of_year")["percentile"]
            .apply(lambda x: REQUIRED_PERCENTILES.issubset(set(x)))
        )

        if doy_ok.all():
            active_ts_ids.append(ts_id)

# Write shard result
Path("artifacts").mkdir(exist_ok=True)
pd.DataFrame({"time_series_id": active_ts_ids}).drop_duplicates().to_parquet(
    f"artifacts/sf_active_ts_ids_shard_{shard_id}.parquet"
)
