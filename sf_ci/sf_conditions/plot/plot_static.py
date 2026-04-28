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
    foreground_image_file,
    usgs_image_file,
    legend_image_file
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
    static_image_file: string
        filepath for the output static image file 
    background_image_file: string
        filepath for the input background image file 
    foreground_image_file: string
        filepath for the input foreground image file 
    usgs_image_file: string
        filepath for the input usgs logo image file 
    legend_image_file: string
        filepath for the input legend image file 
            
    Returns
    -------
        Makes an static formatted image of the current conditions data (image_file)

    """

    # get date
    date = static_image_file[len(static_image_file)  -len("YYYY-MM-DD") -len(".png"): -len(".png")]

    # set defaults for matplotlib
    mpl_setup(figure_params)

    # Set up figure
    fig = plt.figure(1, figsize=(layout_params["figure_dimensions"]))

    # Add background image
    img_background = plt.imread(background_image_file)
    ax_background = fig.add_axes([0, 0, 1, 1])
    ax_background.imshow(img_background)
    ax_background.set_axis_off()

    # Add foreground image
    img_foreground = plt.imread(foreground_image_file)
    ax_foreground = fig.add_axes([0, 0, 1, 1])
    ax_foreground.imshow(img_foreground)
    ax_foreground.set_axis_off()

    # Add usgs image
    img_usgs = plt.imread(usgs_image_file)
    aspect_usgs = img_usgs.shape[1] / img_usgs.shape[0]
    aspect_usgs_ax = aspect_usgs / (layout_params["figure_dimensions"][0] / layout_params["figure_dimensions"][1])
    ax_usgs = fig.add_axes([layout_params["usgs_img_pos"][0], layout_params["usgs_img_pos"][1], layout_params["usgs_img_height"] * aspect_usgs_ax, layout_params["usgs_img_height"]])
    ax_usgs.imshow(img_usgs)
    ax_usgs.set_axis_off()

    # Add legend
    img_legend = plt.imread(legend_image_file)
    legend_height_ax = img_legend.shape[0] / (layout_params["figure_dimensions"][1] * figure_params["dpi"]) * layout_params["legend_scale"]
    legend_length_ax = img_legend.shape[1] / (layout_params["figure_dimensions"][0] * figure_params["dpi"]) * layout_params["legend_scale"]
    ax_legend = fig.add_axes([layout_params["legend_pos"][0], layout_params["legend_pos"][1], legend_length_ax, legend_height_ax])
    ax_legend.imshow(img_legend)
    ax_legend.set_axis_off()

    # add date label
    fig.text(
        figure_params["datelabel"]["xloc"],
        figure_params["datelabel"]["yloc"],
        date_text(date),
        fontsize=figure_params["datelabel"]["fontsize"],
        weight=figure_params["datelabel"]["fontweight"],
        color=figure_params["datelabel"]["fontcolor"],
        ha=figure_params["datelabel"]["ha"],
        va=figure_params["datelabel"]["va"],
    )

    # add temp date label
    fig.text(
        figure_params["datelabel_temp"]["xloc"],
        figure_params["datelabel_temp"]["yloc"],
        date,
        fontsize=figure_params["datelabel_temp"]["fontsize"],
        weight=figure_params["datelabel_temp"]["fontweight"],
        color=figure_params["datelabel_temp"]["fontcolor"],
        ha="right",
        va="top",
    )

    # Save figure
    fig.savefig(static_image_file, dpi = figure_params["dpi"])

    # Close figure
    plt.close(fig)


if __name__ == "__main__":
    figure_params = snakemake.params["figure_params"]
    layout_params = snakemake.params["layout_params"]
    background_image_file = snakemake.input["background_image_file"]
    foreground_image_file = snakemake.input["foreground_image_file"]
    usgs_image_file = snakemake.input["usgs_image_file"]
    legend_image_file = snakemake.input["legend_image_file"]
    static_image_file = snakemake.output["static_image_file"]


    plot_daily_sf_condition(
        figure_params,
        layout_params, 
        static_image_file,
        background_image_file,
        foreground_image_file,
        usgs_image_file,
        legend_image_file)
