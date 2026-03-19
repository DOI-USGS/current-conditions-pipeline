import numpy as np
import pandas as pd
import geopandas as gpd
from scipy.ndimage import gaussian_filter
import matplotlib.pyplot as plt
from sf_conditions.plot.plot_functions import plot_data, get_ax_size_inches, mpl_setup, setup_boundary
    
def plot_daily_sf_condition(
    parquet_file,
    figure_params,
    layout_params, 
    image_file,
    marker_params,
    state_params,
    shadow_image_file
):
    """Set up data and make plots for the given date."""

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
    date = image_file[len(image_file)  -len("YYYY-MM-DD") -len(".png"): -len(".png")]

    # set defaults for matplotlib
    mpl_setup(figure_params)

    # Reference scale to CONUS
    reference_gdf = gpd.read_file(layout_params["geojson"][0])
    minx, miny, maxx, maxy = reference_gdf.to_crs(layout_params["proj"][0]).total_bounds
    reference_length = max(maxx - minx, maxy - miny)

    # Set up figure
    fig = plt.figure(1, figsize=(layout_params["figure_dimensions"]))

    # Add shadow axes
    img_shadow = plt.imread(shadow_image_file)
    img_shadow_blur = gaussian_filter(img_shadow[:, :, 1], sigma=figure_params["shadow"]["sigma"])
    ax_shadow = fig.add_axes([0, 0, 1, 1])
    ax_shadow.imshow(img_shadow_blur, cmap="gray", vmin=0.0, vmax=1.0)
    ax_shadow.set_axis_off()

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
            state_params["style"],
            marker_params,
            figure_params["scale_params"],
            reference_scale,
            reference_length,
            layout_params["scale_bar"][i],
            layout_params["scale_text"][i],
        )

    # add date label
    fig.text(
        figure_params["datelabel"]["xloc"],
        figure_params["datelabel"]["yloc"],
        date,
        fontsize=figure_params["datelabel"]["fontsize"],
        ha="right",
        va="bottom",
    )

    # Save figure
    fig.savefig(image_file, dpi=600)

    # Close figure
    plt.close(fig)


if __name__ == "__main__":
    figure_params = snakemake.params["figure_params"]
    layout_params = snakemake.params["layout_params"]
    state_params = snakemake.params["state_params"]
    marker_params = snakemake.params["marker_params"]
    parquet_file = snakemake.input["parquet_file"]
    shadow_image_file = snakemake.input["shadow_image_file"]
    image_file = snakemake.output["image_file"]


    plot_daily_sf_condition(
        parquet_file,
        figure_params,
        layout_params, 
        image_file,
        marker_params,
        state_params,
        shadow_image_file)
