from tqdm import tqdm
import numpy as np
import pandas as pd
import geopandas as gpd
from shapely import wkt
from sw_conditions.plot.plot_functions import coverage_plot, shadow_plot


def idx_group(g, bins, include_groups=False):
    """Sorts data value from a single site on a single date in percentile bins based on given bin extents for each day-of-year."""

    edges = g[bins].iloc[0].to_numpy()
    # side='right' then subtract 1 mimics [left, right) bins
    idx = np.searchsorted(edges, g["value"].to_numpy(), side="right") - 1
    # Mark out-of-range values (below A or >= D) as -1 (or NaN)
    out = (idx < 0) | (idx >= len(edges) - 1)
    idx[out] = -1
    return pd.Series(idx, index=g.index)


def plot_current_conditions(
    date_list,
    figure_params,
    percentiles_files,
    simplified_census_file,
    marker_params,
    state_params,
):
    """Set up data and make plots for the given date list."""

    us_states_gdf = gpd.read_file(simplified_census_file)

    shadow_plot(
        figure_params,
        us_states_gdf,
        "figures/shadow_" + figure_params["prefix"] + ".png",
        state_params,
    )

    for z, percentiles_file in tqdm(
        enumerate(percentiles_files), desc="Generating plots"
    ):
        # Load parquet file
        dv_df_day = pd.read_parquet(percentiles_file)

        # Convert to geodatabase
        dv_gdf_day = gpd.GeoDataFrame(
            dv_df_day,
            geometry=gpd.GeoSeries.from_wkb(dv_df_day["geometry"], crs="EPSG:4326"),
            crs="EPSG:4326",
        )

        percentile_bins = {
            None: np.nan,
            "NA": np.nan,
            "<0": 0,
            "0-5": 0,
            "5-10": 1,
            "10-25": 2,
            "25-75": 3,
            "75-90": 4,
            "90-95": 5,
            "95-100": 6,
            ">100": 6,
        }
        dv_gdf_day["percentile_bin"] = dv_gdf_day["category"].map(percentile_bins)

        for p_bin in [0, 1, 2, 3, 4, 5, 6]:
            print(p_bin, sum(dv_gdf_day["percentile_bin"] == p_bin))

        print ('NaNs',sum(dv_gdf_day["percentile_bin"].isna()))

        # generate the CONUS + OCONUS plot
        coverage_plot(
            date_list[z],
            figure_params,
            us_states_gdf,
            dv_gdf_day,
            "figures/" + figure_params["prefix"] + "_" + str(date_list[z]) + ".png",
            marker_params,
            state_params,
            "figures/shadow_" + figure_params["prefix"] + ".png",
        )


if __name__ == "__main__":
    date_list = snakemake.params["date_list"]
    figure_params = snakemake.params["figure_params"]
    marker_params = snakemake.params["marker_params"]
    state_params = snakemake.params["state_params"]
    percentiles_files = snakemake.input["percentiles_files"]
    simplified_census_file = snakemake.input["simplified_census_file"]

    plot_current_conditions(
        date_list,
        figure_params,
        percentiles_files,
        simplified_census_file,
        marker_params,
        state_params,
    )
