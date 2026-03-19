import numpy as np
import geopandas as gpd
from matplotlib import rcParams
import matplotlib.pyplot as plt

def mpl_setup(figure_params):
    """Sets the default values for matplotlib."""
    rcParams["font.family"] = figure_params["fontfamily"]
    rcParams["font.sans-serif"] = figure_params["font"]
    rcParams["font.weight"] = figure_params["fontweight"]
    rcParams["font.size"] = figure_params["fontsize"]
    rcParams["text.color"] = figure_params["fontcolor"]


def get_ax_size_inches(ax, fig):
    """Gets the size of the plot area (axes) in inches."""
    bbox = ax.get_window_extent().transformed(fig.dpi_scale_trans.inverted())
    width_inches = bbox.width
    height_inches = bbox.height
    return width_inches, height_inches


def setup_boundary(ax, boundary_gdf_proj, state_style):
    """Plots boundary lines. Removes outer state lines and retains the inner ones."""
    outer_boundary = boundary_gdf_proj.dissolve()
    state_lines_all = boundary_gdf_proj.boundary.unary_union
    usa_outer_lines = outer_boundary.geometry.unary_union.boundary
    inner_lines = state_lines_all.difference(usa_outer_lines)
    if inner_lines.geom_type == "GeometryCollection":
        inner_lines_geoms = [
            g
            for g in inner_lines.geoms
            if g.geom_type in ("LineString", "MultiLineString")
        ]
        inner_state_lines = gpd.GeoSeries(inner_lines_geoms, crs=boundary_gdf_proj.crs)
    else:
        inner_state_lines = gpd.GeoSeries([inner_lines], crs=boundary_gdf_proj.crs)
    outer_boundary.plot(
        ax=ax,
        edgecolor=state_style["outeredgecolor"],
        facecolor=state_style["facecolor"],
        linewidth=state_style["outerlinewidth"],
        zorder=1,
    )
    # If there are no inner statelines (alaska for example, don't plot inner lines)
    if inner_state_lines.is_empty.all() == False:
        inner_state_lines.plot(
            ax=ax,
            color=state_style["edgecolor"],
            linewidth=state_style["linewidth"],
            zorder=1,
            capstyle="round",
            joinstyle="round",
        )


def plot_data(
    fig,
    ax,
    sf_gdf,
    boundary_gdf,
    proj,
    scale_mult,
    state_style,
    marker_params,
    scale_params,
    reference_scale,
    reference_length,
    scale_bar_type,
    scale_text,
):
    """Plots stream flow current conditions data on the specified axis

    Parameters
    ----------
    fig: matplotlib figure
        figure of the plot
    ax: matplotlib axis
        axis in the figure that we are plotting data on
    sf_gdf: geodataframe
        streamflow current conditions data
    boundary_gdf: geodataframe
        boundary geometry
    proj: string
        projection crs
    scale_mult: float
        scale multiplier
    state_style: dictionary
        parameters defining the geometry style
    marker_params: dictionary
        parameters defining the marker style
    scale_params: dictionary
        parameters defining the scale bar style
    reference_scale: float
        reference scale that is in meters (map dimensions) per inch (canvas dimensions)
    reference_length: float
        total width or height (whichever is larger) of the geometries extent
    scale_bar_type: float
        type of scale bar, none, top left corner, or bottom right corner
    scale_text: string
        text to add to the scale bar
            
    Returns
    -------
        Axis with plotted geometry and streamflow current conditions

    """

    # get axis dimensions
    ax_dims = get_ax_size_inches(ax, fig)
    boundary_gdf_proj = boundary_gdf.to_crs(proj)
    setup_boundary(ax, boundary_gdf_proj, state_style)
    minx, miny, maxx, maxy = boundary_gdf_proj.total_bounds
    center_x = 0.5 * (minx + maxx)
    center_y = 0.5 * (miny + maxy)

    # reproject data
    sf_gdf_proj = sf_gdf.to_crs(proj)

    # plot na values
    sf_gdf_proj[sf_gdf_proj["percentile_bin"].isna()].plot(
        ax=ax,
        marker=marker_params["NA"]["marker"],
        color=marker_params["NA"]["color"],
        linewidth=marker_params["NA"]["linewidth"],
        markersize=marker_params["NA"]["size"],
        zorder=marker_params["NA"]["zorder"],
    )

    # dummy marker in case there are no NA values
    ax.scatter(
        -99999999,
        -99999999,
        s=marker_params["NA"]["size"],
        marker=marker_params["NA"]["marker"],
        color=marker_params["NA"]["color"],
        linewidth=marker_params["NA"]["linewidth"],
        zorder=-1,
    )
    
    # plot non na values
    for i in range(0, 7):
        sf_gdf_proj[sf_gdf_proj["percentile_bin"] == float(i)].plot(
            ax=ax,
            marker=marker_params["marker"],
            color=marker_params["facecolor"][i],
            edgecolor=marker_params["edgecolor"][i],
            linewidth=marker_params["linewidth"][i],
            markersize=marker_params["markersize"][i],
            zorder=marker_params["zorder"][i],
        )

    # set up the x and y limits of the axis
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

    if scale_bar_type != False:

        scale_line_size = reference_length * scale_params["scale_length"]
        ax_pos = ax.get_position()

        if scale_bar_type == "upperleft":
            # scale bar location
            scale_bar_x = [
                center_x - 0.5 * reference_scale * ax_dims[0] / scale_mult,
                center_x - 0.5 * reference_scale * ax_dims[0] / scale_mult,
                center_x
                - 0.5 * reference_scale * ax_dims[0] / scale_mult
                + scale_line_size,
            ]
            scale_bar_y = [
                center_y
                + 0.5 * reference_scale * ax_dims[1] / scale_mult
                - scale_line_size,
                center_y + 0.5 * reference_scale * ax_dims[1] / scale_mult,
                center_y + 0.5 * reference_scale * ax_dims[1] / scale_mult,
            ]

            # scale bar text
            if scale_mult.is_integer():
                scale_label = str(round(scale_mult)) + "x " + scale_text
            else:
                scale_label = str(scale_mult) + "x " + scale_text

            scale_text_x = ax_pos.x0 + 0.0025
            scale_text_y = ax_pos.y0 + ax_pos.height - 0.005
            scale_text_ha = "left"
            scale_text_va = "top"
        elif scale_bar_type == "lowerright":
            # scale bar location
            scale_bar_x = [
                center_x + 0.5 * reference_scale * ax_dims[0] / scale_mult,
                center_x + 0.5 * reference_scale * ax_dims[0] / scale_mult,
                center_x
                + 0.5 * reference_scale * ax_dims[0] / scale_mult
                - scale_line_size,
            ]
            scale_bar_y = [
                center_y
                - 0.5 * reference_scale * ax_dims[1] / scale_mult
                + scale_line_size,
                center_y - 0.5 * reference_scale * ax_dims[1] / scale_mult,
                center_y - 0.5 * reference_scale * ax_dims[1] / scale_mult,
            ]

            # scale bar text
            if scale_mult.is_integer():
                scale_label = scale_text + " " + str(round(scale_mult)) + "x"
            else:
                scale_label = scale_text + " " + str(scale_mult) + "x"

            scale_text_x = ax_pos.x0 + ax_pos.width - 0.0025
            scale_text_y = ax_pos.y0 + 0.005
            scale_text_ha = "right"
            scale_text_va = "bottom"
        else:
            print("Wrong scale bar type")

        ax.plot(
            scale_bar_x,
            scale_bar_y,
            color=scale_params["color"],
            linewidth=scale_params["linewidth"],
            clip_on=False,
        )

        ax.text(
            scale_text_x,
            scale_text_y,
            scale_label,
            horizontalalignment=scale_text_ha,
            verticalalignment=scale_text_va,
            transform=fig.transFigure,
            bbox=dict(boxstyle="round,pad=0.5", fc="none", alpha=0.0),
            style="italic",
        )



def make_legend_images(
    marker_params,
    dpi,
):
    """Makes an isolated images of the marker

    Parameters
    ----------
    marker_params: dictionary
        dictionary of parameters for a marker style
    dpi: integer
        resolution, dots per inch
   
    Returns
    -------
        Saved images of isolated markers

    """

    # make small figure
    fig = plt.figure(1, figsize=(0.05, 0.05))

    # add axes
    ax = fig.add_axes([0, 0, 1, 1])

    # remove box around axis
    ax.set_axis_off()

    # NA marker
    ax.scatter(
        0.5,
        0.5,
        s=marker_params["NA"]["size"],
        marker=marker_params["NA"]["marker"],
        color=marker_params["NA"]["color"],
        linewidth=marker_params["NA"]["linewidth"],
    )

    fig.savefig("images/_legend/No-data-marker.svg", dpi=dpi, transparent=True)
    fig.savefig("images/_legend/No-data-marker.png", dpi=dpi, transparent=True)
    ax.cla()

    # non-NA marker
    for i in range(0, 7):
        ax.set_axis_off()
        ax.scatter(
            0.5,
            0.5,
            s=marker_params["markersize"][i],
            marker=marker_params["marker"],
            color=marker_params["facecolor"][i],
            edgecolor=marker_params["edgecolor"][i],
            linewidth=marker_params["linewidth"][i],
        )
        fig.savefig(
            "images/_legend/"
            + marker_params["label"][i].replace(" ", "-")
            + "-marker.svg",
            dpi=dpi,
            transparent=True,
        )
        fig.savefig(
            "images/_legend/"
            + marker_params["label"][i].replace(" ", "-")
            + "-marker.png",
            dpi=dpi,
            transparent=True,
        )
        ax.cla()


def draw_line(p1,p2):
    "Draws a straight interpolated line with 100 points"
    points = 100
    return np.linspace(p1[0],p2[0],points), np.linspace(p1[1],p2[1],points)
      
def draw_box(west,east,south,north):
    "Draws a box with interpolated lines"
    x1,y1 = draw_line([west,south],[east,south])
    x2,y2 = draw_line([east,south],[east,north])
    x3,y3 = draw_line([east,north],[west,north])
    x4,y4 = draw_line([west,north],[west,south])
    return np.concatenate((x1,x2,x3,x4)),np.concatenate((y1,y2,y3,y4))