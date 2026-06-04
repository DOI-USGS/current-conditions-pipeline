import geopandas as gpd
import matplotlib.pyplot as plt
from sf_conditions.plot.plot_functions import get_ax_size_inches

def plot_shadow(fig, ax, boundary_gdf, proj, scale_mult, state_style, reference_scale):
    """Makes an image of the outlines of the map geometries for generated a shadow effect

    Parameters
    ----------
    fig: matplotlib figure
        figure of the plot
    ax: matplotlib axis
        axis in the figure that we are plotting data on
    boundary_gdf: geodataframe
        boundary geometry
    proj: string
        projection crs
    scale_mult: float
        scale multiplier
    state_style: dictionary
        parameters defining the geometry style
    reference_scale: float
        reference scale that is in meters (map dimensions) per inch (canvas dimensions)
            
    Returns
    -------
        Axis with geometry extent in the shadow color

    """

    ax_dims = get_ax_size_inches(ax, fig)
    # project boundary
    boundary_gdf_proj = boundary_gdf.to_crs(proj)

    # plot as `shadow_color`
    boundary_gdf_proj.plot(
        ax=ax,
        facecolor="#000000",
        edgecolor="#000000",
        linewidth=state_style["linewidth"],
        zorder=1,
    )
    minx, miny, maxx, maxy = boundary_gdf_proj.total_bounds
    center_x = 0.5 * (minx + maxx)
    center_y = 0.5 * (miny + maxy)

    # set up axis limits like in `plot_data()`
    ax.set_xlim(
        center_x - 0.5 * reference_scale * ax_dims[0] / scale_mult,
        center_x + 0.5 * reference_scale * ax_dims[0] / scale_mult,
    )
    ax.set_ylim(
        center_y - 0.5 * reference_scale * ax_dims[1] / scale_mult,
        center_y + 0.5 * reference_scale * ax_dims[1] / scale_mult,
    )

    # remove box around axis
    ax.set_axis_off()

def shadow_plot(
    figure_params,
    layout_params, 
    state_params,
    shadow_image_file
):
    """Makes a image of the shadow outline

    Parameters
    ----------
    figure_params: dictionary
        parameters defining the figure style
    layout_params: dictionary
        parameters defining the layout style
    state_params: dictionary
        parameters defining the geometry style
    shadow_image_file: string
        filepath for the shadow outline image
            
    Returns
    -------
        Makes an image of the current conditions data (image_file)

    """
    
    # Reference scale to CONUS
    reference_gdf = gpd.read_file(layout_params["geojson"][0])
    minx, miny, maxx, maxy = reference_gdf.to_crs(layout_params["proj"][0]).total_bounds
    reference_length_x = (maxx - minx)
    reference_length_y = (maxy - miny)

    # Set up figure
    fig = plt.figure(
        1, figsize=(layout_params["figure_dimensions"]), facecolor=figure_params["facecolor"]
    )

    for i, geojson in enumerate(layout_params["geojson"]):
        ax = fig.add_axes(layout_params["ax_loc"][i])
        gdf = gpd.read_file(geojson)

        # reference everything to first geojson
        if i == 0:
            ax_dims = get_ax_size_inches(ax, fig)
            pixel_buffer = figure_params["shadow"]["sigma"] * 4
            inch_buffer = pixel_buffer / figure_params["dpi"]
            if reference_length_x / (ax_dims[0] - inch_buffer) > reference_length_y / (ax_dims[1] - inch_buffer):
                reference_scale = reference_length_x / (ax_dims[0] - inch_buffer)
            else: 
                reference_scale = reference_length_y / (ax_dims[1] - inch_buffer)

        # plot
        plot_shadow(
            fig,
            ax,
            gdf,
            layout_params["proj"][i],
            layout_params["multi"][i],
            state_params["style"],
            reference_scale
        )

    # Save figure
    fig.savefig(shadow_image_file, dpi=figure_params["dpi"])

    # Close figure
    plt.close(fig)

if __name__ == "__main__":
    figure_params = snakemake.params["figure_params"]
    layout_params = snakemake.params["layout_params"]
    state_params = snakemake.params["state_params"]
    shadow_image_file = snakemake.output["shadow_image_file"]

    shadow_plot(
        figure_params,
        layout_params, 
        state_params,
        shadow_image_file
    )
