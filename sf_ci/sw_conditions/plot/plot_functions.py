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
        edgecolor="none",
        facecolor=state_style["facecolor"],
        linewidth=state_style["linewidth"],
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
        -9999,
        -9999,
        s=marker_params["NA"]["size"],
        marker=marker_params["NA"]["marker"],
        color=marker_params["NA"]["color"],
        linewidth=marker_params["NA"]["linewidth"],
        zorder=marker_params["NA"]["zorder"],
        label="Data unavailable - "
        + str(
            round(
                sf_gdf_proj["percentile_bin"].isna().sum() / len(sf_gdf_proj) * 100.0,
                1,
            )
        )
        + "%",
    )

    # plot non na values
    for i in range(0, 8):
        sf_gdf_proj[sf_gdf_proj["percentile_bin"] == float(i)].plot(
            ax=ax,
            marker=marker_params["marker"],
            color=marker_params["facecolor"][i],
            edgecolor=marker_params["edgecolor"][i],
            linewidth=marker_params["linewidth"][i],
            markersize=marker_params["markersize"][i],
            zorder=marker_params["zorder"][i],
            label=marker_params["label"][i],
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
    scale_line_size = reference_length * 0.05
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
    ax.text(
        ax_pos.x0 + 0.0025,
        ax_pos.y0 + ax_pos.height - 0.005,
        str(round(scale_mult)) + "x",
        horizontalalignment="left",
        verticalalignment="top",
        transform=fig.transFigure,
        bbox=dict(boxstyle="round,pad=0.5", fc="none", alpha=0.0),
    )


def coverage_plot(
    date,
    figure_params,
    us_states_gdf,
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
    conus = us_states_gdf[~us_states_gdf["STUSPS"].isin(["HI", "AK", "PR"])]
    minx, miny, maxx, maxy = conus.to_crs(state_params["conus"]["proj"]).total_bounds
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
    pr_ax = fig.add_axes(state_params["puertorico"]["ax_loc"])

    # Get dimensions
    conus_ax_dims = get_ax_size_inches(conus_ax, fig)
    reference_scale = reference_length / conus_ax_dims[0]

    # plot on conus
    plot_data(
        fig,
        conus_ax,
        gdf_sf,
        conus,
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
        us_states_gdf[us_states_gdf["STUSPS"].isin(["AK"])],
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
        us_states_gdf[us_states_gdf["STUSPS"].isin(["HI"])],
        state_params["hawaii"]["proj"],
        state_params["hawaii"]["multi"],
        state_params["style"],
        marker_params,
        figure_params["scale_params"],
        reference_scale,
        reference_length,
    )

    # plot on puerto rico
    plot_data(
        fig,
        pr_ax,
        gdf_sf,
        us_states_gdf[us_states_gdf["STUSPS"].isin(["PR"])],
        state_params["puertorico"]["proj"],
        state_params["puertorico"]["multi"],
        state_params["style"],
        marker_params,
        figure_params["scale_params"],
        reference_scale,
        reference_length,
    )

    # Get legend info
    handles, labels = conus_ax.get_legend_handles_labels()

    # Reverse order
    handles = handles[::-1]
    labels = labels[::-1]

    # Aggregate low and high normal
    handles.pop(3)
    labels.pop(3)
    labels[3] = "Normal"

    # set axis in lower left corner of CONUS plot
    conus_ax.legend(
        handles,
        labels,
        loc="lower left",
        bbox_to_anchor=(-0.025, -0.025),
        frameon=False,
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
    us_states_gdf,
    plotname,
    state_params,
):
    """Sets up the figures with multiple axes for CONUS and OCONUS for the shadow effect."""

    # Reference scale to CONUS
    conus = us_states_gdf[~us_states_gdf["STUSPS"].isin(["HI", "AK", "PR"])]
    minx, miny, maxx, maxy = conus.to_crs(state_params["conus"]["proj"]).total_bounds
    reference_length = maxx - minx

    # Set up figure
    fig = plt.figure(
        1, figsize=(figure_params["dimensions"]), facecolor=figure_params["facecolor"]
    )
    conus_ax = fig.add_axes(state_params["conus"]["ax_loc"])
    ak_ax = fig.add_axes(state_params["alaska"]["ax_loc"])
    hi_ax = fig.add_axes(state_params["hawaii"]["ax_loc"])
    pr_ax = fig.add_axes(state_params["puertorico"]["ax_loc"])

    # Get dimensions
    conus_ax_dims = get_ax_size_inches(conus_ax, fig)
    reference_scale = reference_length / conus_ax_dims[0]

    # plot on conus
    plot_shadow(
        fig,
        conus_ax,
        conus,
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
        us_states_gdf[us_states_gdf["STUSPS"].isin(["AK"])],
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
        us_states_gdf[us_states_gdf["STUSPS"].isin(["HI"])],
        state_params["hawaii"]["proj"],
        state_params["hawaii"]["multi"],
        state_params["style"],
        reference_scale,
        figure_params["shadow"]["color"]
    )

    # plot on puerto rico
    plot_shadow(
        fig,
        pr_ax,
        us_states_gdf[us_states_gdf["STUSPS"].isin(["PR"])],
        state_params["puertorico"]["proj"],
        state_params["puertorico"]["multi"],
        state_params["style"],
        reference_scale,
        figure_params["shadow"]["color"]
    )

    # Save figure
    fig.savefig(plotname, dpi=600)

    # Close figure
    plt.close(fig)
