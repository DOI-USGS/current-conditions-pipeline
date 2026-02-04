import pandas as pd
from pathlib import Path
import sys

sf_pcodes = list(x for x in sys.argv[1].split(","))
sf_stat_ids = list(x for x in sys.argv[2].split(","))

files = list(Path("artifacts").glob("sf_coverage_*.parquet"))

if len(files) == 0:
    sys.exit("No coverage shard artifacts found")


active = pd.concat([pd.read_parquet(f) for f in files], ignore_index=True)
active = active.drop_duplicates()

# Rank statistic_id and parameter_code
stat_rank_map  = {v: i for i, v in enumerate(sf_stat_ids)}
pcode_rank_map = {v: i for i, v in enumerate(sf_pcodes)}

active["stat_rank"]  = active["statistic_id"].map(stat_rank_map).astype('int')
active["pcode_rank"] = active["parameter_code"].map(pcode_rank_map).astype('int')

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
        True,   # monitoring_location_id
        True,   # has_coverage
        False,  # end_utc (most recent first)
        False,  # por_len (longest first)
        True,   # stat_rank (prefer lower)
        True,   # pcode_rank
    ]
)

# Indicate a "preferred" TS ID per monitoring location based on opinionated ranking
active["preferred"] = ~active.duplicated(subset=["monitoring_location_id"], keep="first")
active = active.drop(columns=["stat_rank", "pcode_rank"])

active.to_parquet("artifacts/sf_coverage.parquet")
