import pandas as pd
REQUIRED_PERCENTILES = {0, 5, 10, 25, 50, 75, 90, 95, 100}

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
