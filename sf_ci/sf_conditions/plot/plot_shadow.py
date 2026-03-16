from tqdm import tqdm
import urllib.request
import numpy as np
import pandas as pd
import geopandas as gpd
from sf_conditions.plot.plot_functions import shadow_plot


def plot_shadow_outline(
        figure_params,
        conus_geojson,
        ak_geojson,
        hi_geojson,
        prvi_geojson,
        gump_geojson,
        as_geojson,
        state_params,
        shadow_image_file,
):
    """Set up shadow plot."""

    conus_gdf = gpd.read_file(conus_geojson)
    ak_gdf = gpd.read_file(ak_geojson)
    hi_gdf = gpd.read_file(hi_geojson)
    prvi_gdf = gpd.read_file(prvi_geojson)
    gump_gdf = gpd.read_file(gump_geojson)
    as_gdf = gpd.read_file(as_geojson)

    shadow_plot(
        figure_params,
        conus_gdf,
        ak_gdf,
        hi_gdf,
        prvi_gdf,
        gump_gdf,
        as_gdf,
        shadow_image_file,
        state_params,
    )


if __name__ == "__main__":
    figure_params = snakemake.params["figure_params"]
    state_params = snakemake.params["state_params"]
    conus_geojson = snakemake.input["conus_geojson"]
    ak_geojson = snakemake.input["ak_geojson"]
    hi_geojson = snakemake.input["hi_geojson"]
    prvi_geojson = snakemake.input["prvi_geojson"]
    gump_geojson = snakemake.input["gump_geojson"]
    as_geojson = snakemake.input["as_geojson"]
    shadow_image_file = snakemake.output["shadow_image_file"]

    plot_shadow_outline(
        figure_params,
        conus_geojson,
        ak_geojson,
        hi_geojson,
        prvi_geojson,
        gump_geojson,
        as_geojson,
        state_params,
        shadow_image_file,
    )
