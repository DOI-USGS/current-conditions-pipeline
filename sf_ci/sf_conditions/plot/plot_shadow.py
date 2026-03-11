from tqdm import tqdm
import urllib.request
import numpy as np
import pandas as pd
import geopandas as gpd
from sf_conditions.plot.plot_functions import shadow_plot

def plot_current_conditions(
    figure_params,
    simplified_census_file,
    state_params,
    shadow_image_file
):
    """Set up data and make plots for the given date list."""

    us_states_gdf = gpd.read_file(simplified_census_file)

    shadow_plot(
        figure_params,
        us_states_gdf,
        shadow_image_file,
        state_params,
    )


if __name__ == "__main__":
    figure_params = snakemake.params["figure_params"]
    state_params = snakemake.params["state_params"]
    simplified_census_file = snakemake.input["simplified_census_file"]
    shadow_image_file = snakemake.output["shadow_image_file"]

    plot_current_conditions(
        figure_params,
        simplified_census_file,
        state_params,
        shadow_image_file 
    )
