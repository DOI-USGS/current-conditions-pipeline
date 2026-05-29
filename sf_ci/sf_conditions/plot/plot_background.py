import numpy as np
import pandas as pd
import geopandas as gpd
from scipy.ndimage import gaussian_filter
import matplotlib.pyplot as plt
from mpl_toolkits.basemap import Basemap
from sf_conditions.plot.plot_functions import plot_background, get_ax_size_inches, mpl_setup, draw_gdf_on_basemap, force_grid_linestyle
    
def background_setup(
    figure_params,
    layout_params, 
    background_image_file,
    state_params,
    shadow_image_file
):
    """Makes a background image for the stream flow current conditions viz

    Parameters
    ----------
    figure_params: dictionary
        parameters defining the figure style
    layout_params: dictionary
        parameters defining the layout style
    background_image_file: string
        filepath for the output background image file 
    state_params: dictionary
        parameters defining the geometry style
    shadow_image_file: string
        filepath for the shadow outline image
            
    Returns
    -------
        Makes a background image of the shadow image and boundary geometry data (background_image_file)

    """

    # set defaults for matplotlib
    mpl_setup(figure_params)

    # Set reference scale
    reference_gdf = gpd.read_file(layout_params["geojson"][0])
    minx, miny, maxx, maxy = reference_gdf.to_crs(layout_params["proj"][0]).total_bounds
    reference_length_x = (maxx - minx)
    reference_length_y = (maxy - miny)

    # Set up figure
    fig = plt.figure(1, figsize=(layout_params["figure_dimensions"]), facecolor='none')

    # Add shadow axes
    img_shadow = plt.imread(shadow_image_file)
    alphas = (1. - gaussian_filter(img_shadow[:, :, 1], sigma=figure_params["shadow"]["sigma"])) * figure_params["shadow"]["alpha"]
    ax_shadow = fig.add_axes([0, 0, 1, 1])
    shadow_val = np.min(img_shadow[:, :, 1])
    dark_black = np.zeros_like(alphas)
    ax_shadow.imshow(dark_black, cmap="gray", vmin=0.0, vmax=1.0, alpha = alphas)
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
            pixel_buffer = figure_params["shadow"]["sigma"] * 4
            inch_buffer = pixel_buffer / figure_params["dpi"]
            if reference_length_x / (ax_dims[0] - 2.0 * inch_buffer) > reference_length_y / (ax_dims[1] - 2.0 * inch_buffer):
                reference_scale = reference_length_x / (ax_dims[0] - 2.0 * inch_buffer)
                reference_length = reference_scale * ax_dims[0]
            else: 
                reference_scale = reference_length_y / (ax_dims[1] - 2.0 * inch_buffer)
                reference_length = reference_scale * ax_dims[1]

        # plot
        gdf_extent = plot_background(
            fig,
            ax,
            gdf,
            layout_params["proj"][i],
            layout_params["multi"][i],
            state_params["style"],
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
        map.fillcontinents(color=(0.75,0.75,0.75),lake_color='#FFFFFF')
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

    # Save figure
    if figure_params["webp_quality"] == "lossless":
        fig.savefig(background_image_file, dpi=figure_params["dpi"], pil_kwargs={"lossless": True})
    else:
        fig.savefig(background_image_file, dpi=figure_params["dpi"], pil_kwargs={"quality": figure_params["webp_quality"]})

    # Close figure
    plt.close(fig)


if __name__ == "__main__":
    figure_params = snakemake.params["figure_params"]
    layout_params = snakemake.params["layout_params"]
    state_params = snakemake.params["state_params"]
    shadow_image_file = snakemake.input["shadow_image_file"]
    background_image_file = snakemake.output["background_image_file"]


    background_setup(
        figure_params,
        layout_params, 
        background_image_file,
        state_params,
        shadow_image_file)
