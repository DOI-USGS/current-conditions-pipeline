import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
from sf_conditions.plot.plot_functions import plot_data, get_ax_size_inches, mpl_setup
    
def plot_daily_sf_condition(
    parquet_file,
    figure_params,
    layout_params, 
    image_file,
    marker_params,
):
    """Makes a image of stream flow current conditions, without background geometry or the shadow image

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
            
    Returns
    -------
        Makes an image of current condition markers, foreground image (image_file)

    """

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

    # get date
    date = image_file[len(image_file)  -len("YYYY-MM-DD") -len(".webp"): -len(".webp")]

    # set defaults for matplotlib
    mpl_setup(figure_params)

    # Set reference scale
    reference_gdf = gpd.read_file(layout_params["geojson"][0])
    minx, miny, maxx, maxy = reference_gdf.to_crs(layout_params["proj"][0]).total_bounds
    reference_length = max(maxx - minx, maxy - miny) * figure_params["axis_buffer"]

    # Set up figure
    fig = plt.figure(1, figsize=(layout_params["figure_dimensions"]), facecolor='none')

    for i, geojson in enumerate(layout_params["geojson"]):
        ax = fig.add_axes(layout_params["ax_loc"][i])
        gdf = gpd.read_file(geojson)

        # reference everything to first geojson
        if i == 0:
            ax_dims = get_ax_size_inches(ax, fig)
            if maxx - minx > maxy - miny:
                reference_scale = reference_length / ax_dims[0]
            else: 
                reference_scale = reference_length / ax_dims[1]

        # plot
        plot_data(
            fig,
            ax,
            dv_gdf_day,
            gdf,
            layout_params["proj"][i],
            layout_params["multi"][i],
            marker_params,
            reference_scale
        )

    # Save figure
    if figure_params["webp_quality"] == "lossless":
        fig.savefig(image_file, dpi=figure_params["dpi"], pil_kwargs={"lossless": True})
    else:
        fig.savefig(image_file, dpi=figure_params["dpi"], pil_kwargs={"quality": figure_params["webp_quality"]})

    # Close figure
    plt.close(fig)


if __name__ == "__main__":
    figure_params = snakemake.params["figure_params"]
    layout_params = snakemake.params["layout_params"]
    marker_params = snakemake.params["marker_params"]
    parquet_file = snakemake.input["parquet_file"]
    image_file = snakemake.output["image_file"]


    plot_daily_sf_condition(
        parquet_file,
        figure_params,
        layout_params, 
        image_file,
        marker_params,
    )
