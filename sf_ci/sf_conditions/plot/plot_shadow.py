import geopandas as gpd
import matplotlib.pyplot as plt
from sf_conditions.plot.plot_functions import get_ax_size_inches

def plot_shadow(fig, ax, boundary_gdf, proj, scale_mult, state_style, reference_scale, shadow_color):
    """Sets up solid `shadow_color` geometry on a given axis."""

    ax_dims = get_ax_size_inches(ax, fig)
    # project boundary
    boundary_gdf_proj = boundary_gdf.to_crs(proj)

    # plot as `shadow_color`
    boundary_gdf_proj.plot(
        ax=ax,
        facecolor=shadow_color,
        edgecolor=shadow_color,
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
    
    """Sets up the figures with multiple axes for CONUS and OCONUS for the shadow effect."""
    
    # Reference scale to CONUS
    reference_gdf = gpd.read_file(layout_params["geojson"][0])
    minx, miny, maxx, maxy = reference_gdf.to_crs(layout_params["proj"][0]).total_bounds
    reference_length = max(maxx - minx, maxy - miny)

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
            if maxx - minx > maxy - miny:
                reference_scale = reference_length / ax_dims[0]
            else: 
                reference_scale = reference_length / ax_dims[1]

        # plot
        plot_shadow(
            fig,
            ax,
            gdf,
            layout_params["proj"][i],
            layout_params["multi"][i],
            state_params["style"],
            reference_scale,
            figure_params["shadow"]["color"]
        )

    # Save figure
    fig.savefig(shadow_image_file, dpi=600)

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
