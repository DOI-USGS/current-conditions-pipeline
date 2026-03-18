from tqdm import tqdm
import urllib.request
import numpy as np
import pandas as pd
import geopandas as gpd
from sf_conditions.plot.plot_functions import generate_figure, shadow_plot

def plot_daily_sf_condition(
    figure_params,
    parquet_file,
    image_file,
    simplified_census_file,
    shadow_image_file,
    marker_params,
    state_params,
):
    """Set up data and make plots for the given date."""

    us_states_gdf = gpd.read_file(simplified_census_file)

    # Load parquet file
    dv_df_day = pd.read_parquet(parquet_file)

    # Convert to geodatabase
    dv_gdf_day = gpd.GeoDataFrame(
        dv_df_day,
        geometry=gpd.GeoSeries.from_wkb(dv_df_day["geometry"], crs="EPSG:4326"),
        crs="EPSG:4326",
    )

    # convert en-dash to hyphen if they exist
    dv_gdf_day["category"] = dv_gdf_day["category"].str.replace("\u2013", "-", regex=False)

    # define bin integers for each catergory
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

    # generate the CONUS + OCONUS plot
    date = image_file[len("images/sf-"):-len(".png")]
    generate_figure(
        date,
        figure_params,
        us_states_gdf,
        dv_gdf_day,
        image_file,
        marker_params,
        state_params,
        shadow_image_file,
    )

if __name__ == "__main__":
    figure_params = snakemake.params["figure_params"]
    marker_params = snakemake.params["marker_params"]
    state_params = snakemake.params["state_params"]
    parquet_file = snakemake.input["parquet_file"]
    simplified_census_file = snakemake.input["simplified_census_file"]
    shadow_image_file = snakemake.input["shadow_image_file"]
    image_file = snakemake.output["image_file"]

    plot_daily_sf_condition(
        figure_params,
        parquet_file,
        image_file,
        simplified_census_file,
        shadow_image_file,
        marker_params,
        state_params,
    )
