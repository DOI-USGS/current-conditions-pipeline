import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
from sf_conditions.plot.plot_functions import plot_data, get_ax_size_inches, mpl_setup, date_text
    
def plot_daily_sf_condition(
    figure_params,
    layout_params, 
    static_image_file,
    background_image_file,
    foreground_image_file
):
    """Makes a image of stream flow current conditions

    Parameters
    ----------
    parquet_file: string
        filepath for the parquet file holding the stream flow current conditions data
    figure_params: dictionary
        parameters defining the figure style
    layout_params: dictionary
        parameters defining the layout style
    image_file: string
        filepath for the output image file 
    marker_params: dictionary
        parameters defining the marker style
    state_params: dictionary
        parameters defining the geometry style
    background_image_file: string
        filepath for the shadow outline image
            
    Returns
    -------
        Makes an image of the current conditions data (image_file)

    """

    # get date
    date = static_image_file[len(static_image_file)  -len("YYYY-MM-DD") -len(".png"): -len(".png")]

    # set defaults for matplotlib
    mpl_setup(figure_params)

    # Set up figure
    fig = plt.figure(1, figsize=(layout_params["figure_dimensions"]))

    # Add shadow axes
    img_background = plt.imread(background_image_file)
    ax_background = fig.add_axes([0, 0, 1, 1])
    ax_background.imshow(img_background)
    ax_background.set_axis_off()

    img_foreground = plt.imread(foreground_image_file)
    ax_foreground = fig.add_axes([0, 0, 1, 1])
    ax_foreground.imshow(img_foreground)
    ax_foreground.set_axis_off()

    # add date label
    fig.text(
        figure_params["datelabel"]["xloc"],
        figure_params["datelabel"]["yloc"],
        date_text(date),
        fontsize=figure_params["datelabel"]["fontsize"],
        weight=figure_params["datelabel"]["fontweight"],
        color=figure_params["datelabel"]["fontcolor"],
        ha="left",
        va="top",
    )

    # add temp date label
    fig.text(
        figure_params["datelabel_temp"]["xloc"],
        figure_params["datelabel_temp"]["yloc"],
        date,
        fontsize=figure_params["datelabel_temp"]["fontsize"],
        ha="right",
        va="top",
    )

    # Save figure
    fig.savefig(static_image_file, dpi=600)

    # Close figure
    plt.close(fig)


if __name__ == "__main__":
    figure_params = snakemake.params["figure_params"]
    layout_params = snakemake.params["layout_params"]
    background_image_file = snakemake.input["background_image_file"]
    foreground_image_file = snakemake.input["foreground_image_file"]
    static_image_file = snakemake.output["static_image_file"]


    plot_daily_sf_condition(
        figure_params,
        layout_params, 
        static_image_file,
        background_image_file,
        foreground_image_file)
