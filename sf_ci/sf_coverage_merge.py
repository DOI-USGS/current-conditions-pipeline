import pandas as pd
from pathlib import Path
import sys

sf_pcodes = list(x for x in sys.argv[1].split(","))
sf_stat_ids = list(x for x in sys.argv[2].split(","))

files = list(Path("artifacts").glob("sf_coverage_*.parquet"))

if len(files) == 0:
    sys.exit("No coverage shard artifacts found")


active = pd.concat([pd.read_parquet(f) for f in files], ignore_index=True)
active = active.drop_duplicates(subset=[c for c in active.columns if c != "geometry"])

# Rank statistic_id and parameter_code
stat_rank_map = {v: i for i, v in enumerate(sf_stat_ids)}
pcode_rank_map = {v: i for i, v in enumerate(sf_pcodes)}

active["stat_rank"] = active["statistic_id"].map(stat_rank_map).astype("int")
active["pcode_rank"] = active["parameter_code"].map(pcode_rank_map).astype("int")

# Period-of-record length (days)
active["por_len"] = (active["end_utc"] - active["begin_utc"]).dt.days

# Sort with same priority as groundwater
active = active.sort_values(
    by=[
        "monitoring_location_id",
        "has_coverage",
        "end_utc",
        "por_len",
        "stat_rank",
        "pcode_rank",
    ],
    ascending=[
        True,  # monitoring_location_id
        False,  # has_coverage
        False,  # end_utc (most recent first)
        False,  # por_len (longest first)
        True,  # stat_rank (prefer lower)
        True,  # pcode_rank
    ],
)

# Indicate a "preferred" TS ID per monitoring location based on opinionated ranking
active["preferred"] = ~active.duplicated(subset=["monitoring_location_id"], keep="first")
active = active.drop(columns=["stat_rank", "pcode_rank"])

active.to_parquet("artifacts/sf_coverage.parquet")

# Combine MM-DD percentiles as a single data set across shard IDs
from collections import defaultdict

perc_files = list(Path("artifacts").glob("sf_percentiles_*_*.parquet"))
if len(perc_files) == 0:
    sys.exit("No percentile shard artifacts found")

perc_by_mmdd = defaultdict(list)
for f in perc_files:
    mm_dd = f.stem.rsplit("_", 1)[-1]  # "sf_percentiles_3_04-28" -> "04-28"
    perc_by_mmdd[mm_dd].append(f)

Path("artifacts/sf_percentiles").mkdir(exist_ok=True)
for mm_dd, files in perc_by_mmdd.items():
    merged = pd.concat([pd.read_parquet(f) for f in files], ignore_index=True)
    merged = merged.drop_duplicates()
    # discard rows not in the sf_coverage.parquet data set:
    merged = merged[merged['parent_time_series_id'].isin(active['time_series_id'])]
    merged.to_parquet(f"artifacts/sf_percentiles/sf_percentiles_{mm_dd}.parquet", index=False)
