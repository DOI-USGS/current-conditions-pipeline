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
    stats_file,
    daily_values_file,
    simplified_census_file,
    marker_params,
    state_params,
):
    """Set up data and make plots for the given date list."""

    stats_df = pd.read_parquet(stats_file)

    dv_df = pd.read_parquet(daily_values_file)
    dv_gdf = gpd.GeoDataFrame(
        dv_df, geometry=dv_df["geometry"].apply(wkt.loads), crs="EPSG:4326"
    )

    us_states_gdf = gpd.read_file(simplified_census_file)

    shadow_plot(
        figure_params,
        us_states_gdf,
        "figures/shadow_" + figure_params["prefix"] + ".png",
        state_params,
    )

    for z, date in tqdm(enumerate(date_list), desc="Generating plots"):
        dv_gdf_day = dv_gdf[dv_gdf["time"] == date]
        dv_gdf_day = dv_gdf_day.sort_values(by="last_modified")
        dv_gdf_day = dv_gdf_day[
            ~dv_gdf_day["monitoring_location_id"].duplicated(keep="last")
        ]  # keep newest value

        stats_gdf_day = stats_df[stats_df["time_of_year"] == date[5:]]
        stats_gdf_day = stats_gdf_day[stats_gdf_day["parameter_code"] == "00060"]
        wide = stats_gdf_day.pivot_table(
            index="monitoring_location_id",
            columns="percentile",
            values="value",
            aggfunc="first",
        )

        # Convert to float values
        for colname in wide.columns:
            wide[colname] = wide[colname].astype(float)

        # Interpolate NaN values from adjacent values
        percentiles_df = wide.interpolate(method="linear", axis=1)

        merged = pd.merge(
            dv_gdf_day, percentiles_df, on="monitoring_location_id", how="left"
        )
        merged["percentile_bin"] = merged.groupby(
            "monitoring_location_id", group_keys=False
        ).apply(idx_group, bins = list(percentiles_df.columns), include_groups=False)

        cleaned_merged = merged.copy()
        # NaN values are NaN percentiles
        cleaned_merged.loc[np.isnan(cleaned_merged["value"]), "percentile_bin"] = np.nan
        # Anything above the 100.0 percentile is a 7 category
        cleaned_merged.loc[
            cleaned_merged["value"] >= cleaned_merged[100.0], "percentile_bin"
        ] = 7
        # Anything below the 0.0 percentile is a 0 category
        cleaned_merged.loc[
            cleaned_merged["value"] <= cleaned_merged[0.0], "percentile_bin"
        ] = 0

        # generate the CONUS + OCONUS plot
        coverage_plot(
            date,
            figure_params,
            us_states_gdf,
            cleaned_merged,
            "figures/" + figure_params["prefix"] + "_" + str(date) + ".png",
            marker_params,
            state_params,
            "figures/shadow_" + figure_params["prefix"] + ".png",
        )


if __name__ == "__main__":
    date_list = snakemake.params["date_list"]
    figure_params = snakemake.params["figure_params"]
    marker_params = snakemake.params["marker_params"]
    state_params = snakemake.params["state_params"]
    stats_file = snakemake.input["stats_file"]
    daily_values_file = snakemake.input["daily_values_file"]
    simplified_census_file = snakemake.input["simplified_census_file"]

    plot_current_conditions(
        date_list,
        figure_params,
        stats_file,
        daily_values_file,
        simplified_census_file,
        marker_params,
        state_params,
    )
