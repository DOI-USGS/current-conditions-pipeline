import numpy as np
import pandas as pd
import geopandas as gpd
from scipy.ndimage import gaussian_filter
import matplotlib.pyplot as plt
from mpl_toolkits.basemap import Basemap
from sf_conditions.plot.plot_functions import plot_data, get_ax_size_inches, mpl_setup, draw_gdf_on_basemap, force_grid_linestyle
    
def plot_daily_sf_condition(
    parquet_file,
    figure_params,
    layout_params, 
    image_file,
    marker_params,
    state_params,
    shadow_image_file
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
    shadow_image_file: string
        filepath for the shadow outline image
            
    Returns
    -------
        Makes an image of the current conditions data (image_file)

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
    date = image_file[len(image_file)  -len("YYYY-MM-DD") -len(".png"): -len(".png")]

    # set defaults for matplotlib
    mpl_setup(figure_params)

    # Set reference scale
    reference_gdf = gpd.read_file(layout_params["geojson"][0])
    minx, miny, maxx, maxy = reference_gdf.to_crs(layout_params["proj"][0]).total_bounds
    reference_length = max(maxx - minx, maxy - miny) * figure_params["axis_buffer"]

    # Set up figure
    fig = plt.figure(1, figsize=(layout_params["figure_dimensions"]))

    # Add shadow axes
    img_shadow = plt.imread(shadow_image_file)
    img_shadow_blur = gaussian_filter(img_shadow[:, :, 1], sigma=figure_params["shadow"]["sigma"])
    ax_shadow = fig.add_axes([0, 0, 1, 1])
    ax_shadow.imshow(img_shadow_blur, cmap="gray", vmin=0.0, vmax=1.0)
    ax_shadow.set_axis_off()

    # Make a list of the layout's extents
    if layout_params["locator_map"] == True:
        gdf_list = []
        gdf_extent_list = []

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
        gdf_extent = plot_data(
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

        if layout_params["locator_map"] == True:
            gdf_list += [gdf.to_crs("EPSG:4326")]
            gdf_extent_list += [gdf_extent]

    # make locator map
    if layout_params["locator_map"] == True:
        ax_globe = fig.add_axes(layout_params["locator_map_loc"])
        ax_globe.set_zorder(ax.get_zorder() + 1)

        min_lon, max_lon = 0.0, -180.0 
        min_lat, max_lat = 90.0, 0.0
        for gdf_extent in gdf_extent_list:
            w_lon, e_lon = gdf_extent.total_bounds[0], gdf_extent.total_bounds[2]
            s_lat, n_lat = gdf_extent.total_bounds[1], gdf_extent.total_bounds[3]

            # for US, we'll make sure everything is a negative latitute, across the antimeridian
            if w_lon > 0.0:
                w_lon -= 360.0
            if e_lon > 0.0:
                e_lon -= 360.0
            
            if w_lon < min_lon:
                min_lon = w_lon
            if e_lon > max_lon:
                max_lon = e_lon
            
            if s_lat < min_lat:
                min_lat = s_lat
            if n_lat > max_lat:
                max_lat = n_lat

        # initialize basemap    
        map = Basemap(projection='ortho',lat_0=0.5*(min_lat + max_lat),lon_0=0.5*(min_lon + max_lon),resolution='l')
        # draw circle around globe
        circ = map.drawmapboundary(color='#7F7F7F', linewidth=0.2)
        circ.set_clip_on(False)
        # add countries
        map.fillcontinents(color=(0.75,0.75,0.75),lake_color='#FAFAFA')
        map.drawcountries(linewidth=0.15, color='#B3B3B3')
        # add latitudes and longitudes
        meridians = map.drawmeridians(np.arange(0, 360, 30), linewidth=0.1, color='#A6A6A6')
        parallels = map.drawparallels(np.arange(-90, 90, 30), linewidth=0.1, color='#A6A6A6')
        # set linestyle to solid
        force_grid_linestyle(meridians, linestyle='-', dashes=[])
        force_grid_linestyle(parallels, linestyle='-', dashes=[])

        # draw bounding boxes
        for gdf_extent in gdf_extent_list:
            draw_gdf_on_basemap(gdf_extent,ax_globe,map,'none','k',0.2)
        # draw geometry
        for gdf in gdf_list:
            draw_gdf_on_basemap(gdf,ax_globe,map,'#333333','#333333',0.1)


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
