from dataretrieval import waterdata
import os
import sys
import datetime as dt
import pandas as pd
import numpy as np
from pathlib import Path

min_years_per_yday = int(sys.argv[1])
os.environ["API_USGS_PAT"] = sys.argv[2]

focal_date = dt.date.today() - pd.DateOffset(days = 1)
max_por_start = focal_date - pd.DateOffset(years = min_years_per_yday)

sf_pcodes = ['00060', '00065']
sf_stat_ids = ['00003']
sf_comp_period_ids = ['Daily']



sf_all_ts_ids = waterdata.get_time_series_metadata(
    parameter_code=sf_pcodes,
    statistic_id=sf_stat_ids,
    computation_period_identifier=sf_comp_period_ids,
    begin="1700-01-01/" + str(max_por_start.date()),
    end=str((focal_date - pd.DateOffset(days=1)).date()) + "/..",
    skip_geometry=True,
)[0]

# Ensure date columns are datetime
sf_all_ts_ids["begin_utc"] = pd.to_datetime(sf_all_ts_ids["begin_utc"], format = "mixed", utc = True)
sf_all_ts_ids["end_utc"]   = pd.to_datetime(sf_all_ts_ids["end_utc"], format = "mixed", utc = True)
sf_all_ts_ids["por_len"] = (sf_all_ts_ids["end_utc"] - sf_all_ts_ids["begin_utc"]).dt.days

n_parallel_ci_jobs = 5  # must match gitlab-ci.yml

# Sort so small TS IDs are packed first
sf_all_ts_ids = sf_all_ts_ids.sort_values("por_len")

# Assign group_id and shard_id
sf_all_ts_ids["shard_id"] = (np.arange(len(sf_all_ts_ids)) % n_parallel_ci_jobs).astype(int)

# Final columns
shard_table = sf_all_ts_ids[
    [
        "time_series_id",
        "monitoring_location_id",
        "statistic_id",
        "begin_utc",
        "end_utc",
        "group_id",
        "shard_id",
        "parent_time_series_id"
    ]
]

shard_table = shard_table.loc[:, ~shard_table.columns.duplicated()]

# Write artifact
Path("artifacts").mkdir(exist_ok=True)

shard_table.to_parquet(
    "artifacts/sf_shard_table.parquet"
)
