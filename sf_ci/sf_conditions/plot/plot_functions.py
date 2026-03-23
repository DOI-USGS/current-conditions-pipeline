import numpy as np
import geopandas as gpd
from matplotlib import rcParams
import matplotlib.pyplot as plt
from shapely.geometry import Polygon
from matplotlib.patches import Polygon as mplPolygon
from matplotlib.collections import PatchCollection

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
    extent_gdf: geodataframe
        geodataframe of the extent in NAD83
    not explicitly returned:
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
    # return make_extent_gdf(
    #     center_x - 0.5 * reference_scale * ax_dims[0] / scale_mult,
    #     center_x + 0.5 * reference_scale * ax_dims[0] / scale_mult,
    #     center_y - 0.5 * reference_scale * ax_dims[1] / scale_mult,
    #     center_y + 0.5 * reference_scale * ax_dims[1] / scale_mult,
    #     proj,
    # )
    return make_extent_gdf(
        boundary_gdf,
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


def make_extent_gdf(gdf, buffer = 1, int_pnts = 10):
    "Create extent geodataframe in geographic coordinates"

    lons = []
    lats = []

    for geom in gdf.geometry:
        if geom.is_empty:
            continue

        if geom.geom_type == "Polygon":
            x, y = geom.exterior.xy
            lons.extend(x)
            lats.extend(y)

        elif geom.geom_type == "MultiPolygon":
            for poly in geom.geoms:
                x, y = poly.exterior.xy
                lons.extend(x)
                lats.extend(y)
        else:
            raise ValueError("Expected Polygon or MultiPolygon geometries.")

    lons = np.asarray(lons)
    lats = np.asarray(lats)

    lon_list = []
    lat_list = []

    south = np.min(lats) - buffer
    north = np.max(lats) + buffer
    # deal with antimeridian objects
    if np.min(lons) < 0.0 and np.max(lons) > 0.0:
        west = np.min(lons[lons>0.0]) - buffer
        east = np.max(lons[lons<0.0]) + buffer

        lon_pnts = [west, west, 180., -180., east, east, -180., 180., west]
        lat_pnts = [north, south, south, south, south, north, north, north, north]

        for i in range(0,len(lon_pnts)-1):
            if i == 2 or i ==6:
                pass
            else:
                for j in range(0,int_pnts):
                    lon_list += [np.linspace(lon_pnts[i],lon_pnts[i+1],int_pnts)[j]]
                    lat_list += [np.linspace(lat_pnts[i],lat_pnts[i+1],int_pnts)[j]]
    else:
        west = np.min(lons) - buffer
        east = np.max(lons) + buffer
        lon_pnts = [west, west, east, east, west]
        lat_pnts = [north, south, south, north, north]

        for i in range(0,len(lon_pnts)-1):
            for j in range(0,int_pnts):
                lon_list += [np.linspace(lon_pnts[i],lon_pnts[i+1],int_pnts)[j]]
                lat_list += [np.linspace(lat_pnts[i],lat_pnts[i+1],int_pnts)[j]]

    # create geometry from extent
    domain_geom = Polygon(
        zip(
            lon_list,
            lat_list,
        )
    )

    # Create a geopandas dataframe from the polygon and set the CRS
    domain_polygon = gpd.GeoDataFrame(index=[0], crs=gdf.crs, geometry=[domain_geom])

    # return in geographic coordinates EPSG:4326, WGS 84
    return domain_polygon.to_crs("EPSG:4326")


def draw_gdf_on_basemap(gdf,ax,map,facecolor,edgecolor,linewidth):
    patches = []

    polys = gdf[gdf.geometry.geom_type.isin(["Polygon", "MultiPolygon"])]

    for geom in polys.geometry:
        if geom.geom_type == "Polygon":
            # Exterior ring
            xs, ys = geom.exterior.xy
            mx, my = map(xs, ys)
            patches.append(mplPolygon(np.column_stack([mx, my]), closed=True))
            # Interior rings (holes)
            for interior in geom.interiors:
                xs, ys = interior.xy
                mx, my = map(xs, ys)
                patches.append(mplPolygon(np.column_stack([mx, my]), closed=True))
        else:
            # MultiPolygon
            for part in geom.geoms:
                xs, ys = part.exterior.xy
                mx, my = map(xs, ys)
                patches.append(mplPolygon(np.column_stack([mx, my]), closed=True))
                for interior in part.interiors:
                    xs, ys = interior.xy
                    mx, my = map(xs, ys)
                    patches.append(mplPolygon(np.column_stack([mx, my]), closed=True))

    # Add as a collection
    pc = PatchCollection(
        patches,
        facecolor=facecolor,
        edgecolor=edgecolor,
        linewidths=linewidth,
        zorder = 10
    )

    ax.add_collection(pc)

def force_grid_linestyle(grid_dict, linestyle='-', dashes=None):
    """
    Basemap drawmeridians/drawparallels return a dict:
      - {value: [Line2D, ...]} or
      - {value: ( [Line2D, ...], [Text, ...] )} when labels are on.
    This function sets the linestyle/dashes on every Line2D/LineCollection in there.
    """
    for _, entry in grid_dict.items():
        # entry can be a list of lines, or a tuple: (lines_list, labels_list)
        if isinstance(entry, tuple):
            lines = entry[0]
        elif isinstance(entry, list):
            lines = entry
        else:
            lines = [entry]  # Just in case of odd return types

        for line in lines:
            # Line2D and LineCollection both support set_linestyle
            if hasattr(line, 'set_linestyle'):
                line.set_linestyle(linestyle)
            # Some objects support set_dashes; empty list forces solid
            if dashes is not None and hasattr(line, 'set_dashes'):
                line.set_dashes(dashes)