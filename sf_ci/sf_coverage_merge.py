import pandas as pd
from pathlib import Path

files = Path("artifacts").glob("sf_coverage_*.parquet")

active = pd.concat([pd.read_parquet(f) for f in files], ignore_index=True)
active = active.drop_duplicates()

active.to_parquet("artifacts/sf_coverage.parquet")
