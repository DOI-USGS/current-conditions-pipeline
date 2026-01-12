from dataretrieval import waterdata
import os
import datetime as dt
import pandas as pd
import numpy as np
from pathlib import Path

min_years_per_yday = int(sys.argv[1])

focal_date = dt.date.today() - pd.DateOffset(days = 1)
max_por_start = focal_date - pd.DateOffset(years = min_years_per_yday)

sf_pcodes = ['00060', '00065']
sf_stat_ids = ['00003', '00011']
sf_comp_period_ids = ['Daily', 'Points']

sf_all_ts_ids = waterdata.get_time_series_metadata(
    parameter_code=sf_pcodes,
    statistic_id=sf_stat_ids,
    computation_period_identifier=sf_comp_period_ids,
    begin="1700-01-01/" + str(max_por_start.date()),
    end=str((focal_date - pd.DateOffset(days=1)).date()) + "/..",
    skip_geometry=True,
)

sf_filt_ts_ids = sf_all_ts_ids[0].copy()

# Ensure date columns are datetime
sf_filt_ts_ids["begin_utc"] = pd.to_datetime(sf_filt_ts_ids["begin_utc"], format = "mixed", utc = True)
sf_filt_ts_ids["end_utc"]   = pd.to_datetime(sf_filt_ts_ids["end_utc"], format = "mixed", utc = True)

# Rank statistic_id and parameter_code
stat_rank_map  = {v: i for i, v in enumerate(sf_stat_ids)}
pcode_rank_map = {v: i for i, v in enumerate(sf_pcodes)}

sf_filt_ts_ids["stat_rank"]  = sf_filt_ts_ids["statistic_id"].map(stat_rank_map).astype('int')
sf_filt_ts_ids["pcode_rank"] = sf_filt_ts_ids["parameter_code"].map(pcode_rank_map).astype('int')

# Period-of-record length (days)
sf_filt_ts_ids["por_len"] = (sf_filt_ts_ids["end_utc"] - sf_filt_ts_ids["begin_utc"]).dt.days

# Sort with same priority as groundwater
sf_filt_ts_ids = sf_filt_ts_ids.sort_values(
    by=[
        "monitoring_location_id",
        "stat_rank",
        "por_len",
        "end_utc",
        "pcode_rank",
    ],
    ascending=[
        True,   # monitoring_location_id
        True,   # stat_rank (prefer lower)
        False,  # por_len (longest first)
        False,  # end_utc (most recent first)
        True,   # pcode_rank
    ]
)

# Keep one TS per monitoring location
sf_filt_ts_ids = (
    sf_filt_ts_ids
    .groupby("monitoring_location_id", as_index=False)
    .head(1)
    .drop(columns=["stat_rank", "pcode_rank"])
)

ideal_rows_per_shard = 50_000
n_parallel_ci_jobs = 10  # must match gitlab-ci.yml

sf_filt_ts_ids = sf_filt_ts_ids[sf_filt_ts_ids["statistic_id"].isin(["00003"])]

# Estimate number of rows per TS
sf_filt_ts_ids["est_rows"] = np.where(
    sf_filt_ts_ids["statistic_id"] == "00003",
    sf_filt_ts_ids["por_len"],            # daily
    sf_filt_ts_ids["por_len"] * 4 * 24    # continuous (15-min)
)

# Sort so small TS IDs are packed first
sf_filt_ts_ids = sf_filt_ts_ids.sort_values("est_rows")

# Assign group_id and shard_id
sf_filt_ts_ids["group_id"] = ((sf_filt_ts_ids["est_rows"].cumsum() - 1) // ideal_rows_per_shard).astype(int)
sf_filt_ts_ids["shard_id"] = (sf_filt_ts_ids["group_id"] % n_parallel_ci_jobs).astype(int)

# Final columns
shard_table = sf_filt_ts_ids[
    [
        "time_series_id",
        "statistic_id",
        "begin_utc",
        "end_utc",
        "group_id",
        "shard_id",
    ]
]

shard_table = shard_table.loc[:, ~shard_table.columns.duplicated()]

# Write artifact
Path("artifacts").mkdir(exist_ok=True)

shard_table.to_parquet(
    "artifacts/sf_shard_table.parquet"
)
