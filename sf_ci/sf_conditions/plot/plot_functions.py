import numpy as np
import pandas as pd
from pygris import states
import geopandas as gpd
from PIL import Image
from scipy.ndimage import gaussian_filter
from matplotlib import font_manager
from matplotlib import rcParams
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection


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
):
    """Plots surface water data on the specified axis."""

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

    # scale bar
    scale_line_size = reference_length * scale_params["scale_length"]
    ax.plot(
        [
            center_x - 0.5 * reference_scale * ax_dims[0] / scale_mult,
            center_x - 0.5 * reference_scale * ax_dims[0] / scale_mult,
            center_x
            - 0.5 * reference_scale * ax_dims[0] / scale_mult
            + scale_line_size,
        ],
        [
            center_y
            + 0.5 * reference_scale * ax_dims[1] / scale_mult
            - scale_line_size,
            center_y + 0.5 * reference_scale * ax_dims[1] / scale_mult,
            center_y + 0.5 * reference_scale * ax_dims[1] / scale_mult,
        ],
        color=scale_params["color"],
        linewidth=scale_params["linewidth"],
        clip_on=False,
    )

    # scale bar text
    ax_pos = ax.get_position()
    if scale_mult.is_integer():
        scale_label = str(round(scale_mult)) + "x"
    else:
        scale_label = str(scale_mult) + "x"

    ax.text(
        ax_pos.x0 + 0.0025,
        ax_pos.y0 + ax_pos.height - 0.005,
        scale_label,
        horizontalalignment="left",
        verticalalignment="top",
        transform=fig.transFigure,
        bbox=dict(boxstyle="round,pad=0.5", fc="none", alpha=0.0),
    )


def generate_figure(
    date,
    figure_params,
    conus_gdf,
    ak_gdf,
    hi_gdf,
    prvi_gdf,
    gump_gdf,
    as_gdf,
    gdf_sf,
    plotname,
    marker_params,
    state_params,
    shadow_image,
):
    """Sets up the figures with multiple axes for CONUS and OCONUS."""

    # set defaults for matplotlib
    mpl_setup(figure_params)

    # Reference scale to CONUS
    minx, miny, maxx, maxy = conus_gdf.to_crs(state_params["conus"]["proj"]).total_bounds
    reference_length = maxx - minx

    # Set up figure
    fig = plt.figure(1, figsize=(figure_params["dimensions"]))

    # Add shadow axes
    img_shadow = plt.imread(shadow_image)
    img_shadow_blur = gaussian_filter(img_shadow[:, :, 1], sigma=figure_params["shadow"]["sigma"])
    ax_shadow = fig.add_axes([0, 0, 1, 1])
    ax_shadow.imshow(img_shadow_blur, cmap="gray", vmin=0.0, vmax=1.0)
    ax_shadow.set_axis_off()

    # Add regional axes
    conus_ax = fig.add_axes(state_params["conus"]["ax_loc"])
    ak_ax = fig.add_axes(state_params["alaska"]["ax_loc"])
    hi_ax = fig.add_axes(state_params["hawaii"]["ax_loc"])
    prvi_ax = fig.add_axes(state_params["puertoricoandvirginislands"]["ax_loc"])
    gump_ax = fig.add_axes(state_params["marianaislands"]["ax_loc"])
    as_ax = fig.add_axes(state_params["americansomoa"]["ax_loc"])

    # Get dimensions
    conus_ax_dims = get_ax_size_inches(conus_ax, fig)
    reference_scale = reference_length / conus_ax_dims[0]

    # plot on conus
    plot_data(
        fig,
        conus_ax,
        gdf_sf,
        conus_gdf,
        state_params["conus"]["proj"],
        state_params["conus"]["multi"],
        state_params["style"],
        marker_params,
        figure_params["scale_params"],
        reference_scale,
        reference_length,
    )

    # plot on alaska
    plot_data(
        fig,
        ak_ax,
        gdf_sf,
        ak_gdf,
        state_params["alaska"]["proj"],
        state_params["alaska"]["multi"],
        state_params["style"],
        marker_params,
        figure_params["scale_params"],
        reference_scale,
        reference_length,
    )

    # plot on hawaii
    plot_data(
        fig,
        hi_ax,
        gdf_sf,
        hi_gdf,
        state_params["hawaii"]["proj"],
        state_params["hawaii"]["multi"],
        state_params["style"],
        marker_params,
        figure_params["scale_params"],
        reference_scale,
        reference_length,
    )

    # plot on puerto rico and virgin islands
    plot_data(
        fig,
        prvi_ax,
        gdf_sf,
        prvi_gdf,
        state_params["puertoricoandvirginislands"]["proj"],
        state_params["puertoricoandvirginislands"]["multi"],
        state_params["style"],
        marker_params,
        figure_params["scale_params"],
        reference_scale,
        reference_length,
    )

    # plot on northern mariana islands
    plot_data(
        fig,
        gump_ax,
        gdf_sf,
        gump_gdf,
        state_params["marianaislands"]["proj"],
        state_params["marianaislands"]["multi"],
        state_params["style"],
        marker_params,
        figure_params["scale_params"],
        reference_scale,
        reference_length,
    )

    # plot on american somoa
    plot_data(
        fig,
        as_ax,
        gdf_sf,
        as_gdf,
        state_params["americansomoa"]["proj"],
        state_params["americansomoa"]["multi"],
        state_params["style"],
        marker_params,
        figure_params["scale_params"],
        reference_scale,
        reference_length,
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
    fig.savefig(plotname, dpi=600)

    # Close figure
    plt.close(fig)


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
    conus_gdf,
    ak_gdf,
    hi_gdf,
    prvi_gdf,
    gump_gdf,
    as_gdf,
    plotname,
    state_params,
):
    """Sets up the figures with multiple axes for CONUS and OCONUS for the shadow effect."""

    # Reference scale to CONUS
    minx, miny, maxx, maxy = conus_gdf.to_crs(state_params["conus"]["proj"]).total_bounds
    reference_length = maxx - minx

    # Set up figure
    fig = plt.figure(
        1, figsize=(figure_params["dimensions"]), facecolor=figure_params["facecolor"]
    )
    conus_ax = fig.add_axes(state_params["conus"]["ax_loc"])
    ak_ax = fig.add_axes(state_params["alaska"]["ax_loc"])
    hi_ax = fig.add_axes(state_params["hawaii"]["ax_loc"])
    prvi_ax = fig.add_axes(state_params["puertoricoandvirginislands"]["ax_loc"])
    gump_ax = fig.add_axes(state_params["marianaislands"]["ax_loc"])
    as_ax = fig.add_axes(state_params["americansomoa"]["ax_loc"])

    # Get dimensions
    conus_ax_dims = get_ax_size_inches(conus_ax, fig)
    reference_scale = reference_length / conus_ax_dims[0]

    # plot on conus
    plot_shadow(
        fig,
        conus_ax,
        conus_gdf,
        state_params["conus"]["proj"],
        state_params["conus"]["multi"],
        state_params["style"],
        reference_scale,
        figure_params["shadow"]["color"]
    )

    # plot on alaska
    plot_shadow(
        fig,
        ak_ax,
        ak_gdf,
        state_params["alaska"]["proj"],
        state_params["alaska"]["multi"],
        state_params["style"],
        reference_scale,
        figure_params["shadow"]["color"]
    )

    # plot on hawaii
    plot_shadow(
        fig,
        hi_ax,
        hi_gdf,
        state_params["hawaii"]["proj"],
        state_params["hawaii"]["multi"],
        state_params["style"],
        reference_scale,
        figure_params["shadow"]["color"]
    )

    # plot on puerto rico and virgin islands
    plot_shadow(
        fig,
        prvi_ax,
        prvi_gdf,
        state_params["puertoricoandvirginislands"]["proj"],
        state_params["puertoricoandvirginislands"]["multi"],
        state_params["style"],
        reference_scale,
        figure_params["shadow"]["color"]
    )

    # plot on northern mariana islands
    plot_shadow(
        fig,
        gump_ax,
        gump_gdf,
        state_params["marianaislands"]["proj"],
        state_params["marianaislands"]["multi"],
        state_params["style"],
        reference_scale,
        figure_params["shadow"]["color"]
    )

    # plot on american somoa
    plot_shadow(
        fig,
        as_ax,
        as_gdf,
        state_params["americansomoa"]["proj"],
        state_params["americansomoa"]["multi"],
        state_params["style"],
        reference_scale,
        figure_params["shadow"]["color"]
    )

    # Save figure
    fig.savefig(plotname, dpi=600)

    # Close figure
    plt.close(fig)
