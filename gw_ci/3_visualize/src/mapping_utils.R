#' Build the base groundwater map for one area
#'
#' Handles background layers:
#' fill, shadow/glow, and state or area boundaries.
#'
#' @param area_name Name of area.
#' @param area_sf sf polygons for the area.
#' @param viz_cfg Visualization config.
#'
#' @return A ggplot object containing only the base map layers.
plot_base <- function(area_name, area_sf, viz_cfg) {
  # For CONUS, extract additional geometries for plotting
  if (area_name == "CONUS") {
    # Extract internal lines
    conus_inner_states_sf <- rmapshaper::ms_innerlines(area_sf)
    # Extract outer boundary
    conus_outer_boundary_sf <- area_sf |>
      sf::st_union() |>
      sf::st_cast("MULTILINESTRING")
  }

  base_layers <- list(
    ggfx::with_shadow(
      geom_sf(
        data = area_sf,
        fill = viz_cfg$bg_col,
        color = NA
      ),
      colour = viz_cfg$ggfx_col,
      x_offset = 0,
      y_offset = 0,
      sigma = viz_cfg$ggfx_sigma
    )
  )

  boundary_layers <- if (area_name == "CONUS") {
    list(
      geom_sf(
        data = conus_inner_states_sf,
        color = viz_cfg$inner_states_col,
        linewidth = viz_cfg$inner_states_stroke,
        fill = NA
      ),
      geom_sf(
        data = conus_outer_boundary_sf,
        color = viz_cfg$outer_states_col,
        linewidth = viz_cfg$outer_states_stroke,
        fill = NA
      )
    )
  } else {
    list(
      geom_sf(
        data = area_sf,
        color = viz_cfg$outer_states_col,
        linewidth = viz_cfg$outer_states_stroke,
        fill = NA
      )
    )
  }

  # Build plot
  p <- ggplot() +
    base_layers +
    boundary_layers

  return(p)
}

#' Read and prepare groundwater data for plotting
#'
#' Reads a groundwater parquet, converts to sf, reprojects, filters to area,
#' joins state lookup, and computes plotting geometry.
#'
#' @param gw_parquet_file Path to processed parquet file for one date.
#' @param area_proj Projection to use for the area.
#' @param area_state_list List of states within area.
#' @param state_lookup State lookup table.
#' @param scale_cfg Scaling config.
#'
#' @return sf object prepared for plotting.
prepare_gw_plot_data <- function(gw_parquet_file, area_proj, area_state_list,
                                 state_lookup, scale_cfg) {
  # Read and convert to sf, join area, drop sites not in area
  gw_sf <- arrow::read_parquet(gw_parquet_file) |>
    sf::st_as_sf() |>
    # Must set CRS to EPSG:4326 first then transform
    sf::st_set_crs(sf::st_crs("EPSG:4326")) |>
    # Transform to crs for area
    sf::st_transform(area_proj) |>
    dplyr::left_join(state_lookup, by = c("state_name" = "state_name_std")) |>
    dplyr::filter(state_abbr %in% unlist(area_state_list))

  gw_sf <- gw_sf |>
    compute_peak_geometry(scale_cfg) |>
    dplyr::arrange(plotting_order, desc(y))

  return(gw_sf)
}

#' Build groundwater symbol layers for one area/date
#'
#' @param gw_plot_order Prepared groundwater plotting data.
#' @param palette Named color vector.
#' @param viz_cfg Visualization config.
#' @param image_screen_type Type of screen image is intended for such as
#'   "desktop" or "mobile".
#'
#' @return A list of ggplot layers/scales.
plot_gw_symbols <- function(gw_plot_order, palette, viz_cfg, image_screen_type) {
  na_sites_size <- ifelse(
    image_screen_type == "mobile",
    viz_cfg$na_sites_size_mobile,
    viz_cfg$na_sites_size_desktop
  )

  symbol_layers <- list(
    geom_sf(
      # NA sites
      data = dplyr::filter(gw_plot_order, is.na(per_bin)),
      color = viz_cfg$na_sites_col,
      shape = 4,
      size = na_sites_size,
      stroke = viz_cfg$na_sites_stroke
    ),
    geom_segment(
      # Plotting order 1: horizontal lines
      data = dplyr::filter(gw_plot_order, plotting_order == 1),
      aes(
        x = x_start,
        xend = x_end,
        y = y,
        yend = y_end,
        color = per_bin
      ),
      linewidth = viz_cfg$normal_sites_stroke
    )
  )

  sites_order_2_to_4 <- gw_plot_order |>
    dplyr::filter(plotting_order %in% 2:4) |>
    dplyr::pull(monitoring_location_id) |>
    unique()

  # For each site, plot mask, gradient, and border
  peak_layers <- purrr::map(sites_order_2_to_4, function(site) {
    site_gw <- dplyr::filter(gw_plot_order, monitoring_location_id == site)

    border1_white <- geom_segment(
      data = site_gw,
      aes(
        x = x_start,
        xend = x,
        y = y,
        yend = y_end
      ),
      color = "white",
      linewidth = 0.4
    )
    
    border2_white <- geom_segment(
      data = site_gw,
      aes(
        x = x,
        xend = x_end,
        y = y_end,
        yend = y
      ),
      color = "white",
      linewidth = 0.4
    )
    
    # Layer 1: mask
    mask <- geom_link(
      data = site_gw,
      aes(
        x = x,
        xend = x,
        y = y,
        yend = y_end,
        group = monitoring_location_id,
        peak_width = peak_width,
        linewidth = after_stat(I((1 - index) * peak_width)),
        alpha = after_stat(I((0.03^index - 1) / (0.03- 1)))
        ),
      color = "white"
    )

    # Layer 2: gradient
    gradient <- geom_link(
      data = site_gw,
      aes(
        x = x,
        xend = x,
        y = y,
        yend = y_end,
        color = per_bin,
        group = monitoring_location_id,
        peak_width = peak_width,
        linewidth = after_stat(I((1 - index) * peak_width)),
        alpha = after_stat(I((0.03^index - 1) / (0.03- 1)))
      )
    )
    
    border1 <- geom_segment(
      data = site_gw,
      aes(
        x = x_start,
        xend = x ,
        y = y,
        yend = y_end,
        color = per_bin
      ),
      linewidth = 0.1
    )
    
    border2 <- geom_segment(
      data = site_gw,
      aes(
        x = x,
        xend = x_end,
        y = y_end,
        yend = y,
        color = per_bin
      ),
      linewidth = 0.1
    )

    list(border1_white, border2_white, mask, gradient, border1, border2)
    
  }) |>
    purrr::flatten()

  return(c(
    symbol_layers,
    peak_layers,
    list(
      scale_color_manual(values = palette)
    )
  ))
}

#' Build a groundwater plot for one date for a given area
#'
#' Reads processed parquet data, filters to area, reprojects spatial data,
#' renders the groundwater map
#'
#' @param gw_parquet_file Path to processed parquet file for one date.
#' @param date_val Date for which gw data are being plotted.
#' @param incl_date Boolean - Include date on plot.
#' @param area_name Name of area
#' @param area_proj proj to use for `area`
#' @param area_state_list list of states within `area`
#' @param area_sf sf of polygons for the area
#' @param palette Named color vector.
#' @param viz_cfg Visualization config.
#' @param scale_cfg Scaling config.
#' @param state_lookup State lookup table.
#' @param image_screen_type Type of screen image is intended for, e.g.
#'   "desktop" or "mobile".
#' @param base_plot Optional ggplot base map. If NULL and `draw_base = TRUE`,
#'   `plot_base()` is used.
#' @param draw_base Logical; if TRUE, include base map layers.
#' @param draw_symbols Logical; if TRUE, include groundwater symbol layers.
#'
#' @return Final ggplot.
plot_gw <- function(gw_parquet_file, date_val, incl_date, area_name, area_proj,
                    area_state_list, area_sf, palette, viz_cfg, scale_cfg,
                    state_lookup, image_screen_type, base_plot = NULL,
                    draw_base = TRUE, draw_symbols = TRUE) {
  # Validate
  if (!draw_base && !draw_symbols) {
    stop("plot_gw(): At least one of draw_base or draw_symbols must be TRUE")
  }

  # Use provided base_plot or build one if needed
  p <- if (draw_base) {
    base_plot %||% plot_base(
      area_name = area_name,
      area_sf = area_sf,
      viz_cfg = viz_cfg
    )
  } else {
    NULL
  }

  # Add symbols
  if (draw_symbols) {
    gw_plot_order <- prepare_gw_plot_data(
      gw_parquet_file = gw_parquet_file,
      area_proj = area_proj,
      area_state_list = area_state_list,
      state_lookup = state_lookup,
      scale_cfg = scale_cfg
    )

    symbol_layers <- plot_gw_symbols(
      gw_plot_order = gw_plot_order,
      palette = palette,
      viz_cfg = viz_cfg,
      image_screen_type = image_screen_type
    )

    p <- if (is.null(p)) {
      ggplot() + symbol_layers
    } else {
      p + symbol_layers
    }
  }

  # Ensure plot exists
  if (is.null(p)) {
    p <- ggplot()
  }

  p <- p +
    theme_void() +
    theme(legend.position = "none")

  if (incl_date) {
    p <- p + labs(title = date_val)
  }

  return(p)
}

#' Build and save a groundwater image for one date for a given area
#'
#' Reads processed parquet data, filters to area, reprojects spatial data,
#' renders the groundwater map, and saves the png
#'
#' @param gw_parquet_file Path to processed parquet file for one date.
#' @param date Date for which gw data are being plotted.
#' @param area_name Name of area.
#' @param area_info_df dataframe with information about the area for which to
#' plot gw data, including the name of area, the projection to use for the area,
#' and the list of states within the area
#' @param area_sf sf of polygons for the area, or list of sf object for areas
#' @param extent_info spatial extent information for area_sf
#' @param palette Named color vector.
#' @param viz_cfg Visualization config.
#' @param scale_cfg Scaling config.
#' @param state_lookup State lookup table.
#' @param locator_map_png filepath to png of locator map for `area_name`. NULL
#' by default. Currently only used for CONUS_OCONUS layout
#' @param image_screen_type Type of screen image is intended for, e.g., "desktop"
#' or "mobile". Used to build output filename, along with `area_name` and `date`
#' @param output_template Filename template containing `%s` for date.
#' @param layer_mode Character; one of "full", "foreground", or "background".
#'   Controls which map layers are rendered.
#' @param output_format Character; output file format ("png" or "webp").
#' @param transparent_bg Logical; if TRUE, export with transparent background.
#' @return Character string path to saved PNG or webp.
plot_gw_image <- function(gw_parquet_file, date, area_name, area_info_df, area_sf,
                          extent_info, palette, viz_cfg, scale_cfg,
                          state_lookup, locator_map_png = NULL,
                          image_screen_type, output_template,
                          layer_mode, output_format, transparent_bg) {
  date_val <- as.character(date)
  if (grepl("%", output_template)) {
    out_path <- sprintf(output_template, image_screen_type, area_name, date_val)
  } else {
    out_path <- output_template
  }

  # normalize once
  layer_mode <- tolower(trimws(layer_mode))
  output_format <- tolower(trimws(output_format))

  # validate early
  valid_layer_modes <- c("full", "foreground", "background")
  if (!layer_mode %in% valid_layer_modes) {
    stop(sprintf("layer_mode must be one of: %s", paste(valid_layer_modes,
      collapse = ", "
    )))
  }

  if (output_format != "webp") {
    stop("While png creation is possible, plot_gw_image() encourages webp
         output. Pngs are generated downstream via plot_gw_static_png() ")
  }

  # derive behavior from layer_mode
  draw_base <- layer_mode %in% c("full", "background")
  draw_symbols <- layer_mode %in% c("full", "foreground")
  draw_labels <- layer_mode %in% c("full", "background")
  draw_scale_markers <- layer_mode %in% c("full", "background")
  is_foreground <- layer_mode == "foreground"

  message(sprintf(
    "read in %s, plot %s (%s layer) for %s, and save as %s",
    gw_parquet_file,
    area_name,
    layer_mode,
    date_val,
    out_path
  ))

  # Ensure the directory exists so ggsave doesn't error
  if (!dir.exists(dirname(out_path))) dir.create(dirname(out_path), recursive = TRUE)

  # Build base plot
  base_plot <- NULL
  if (draw_base && area_name != "CONUS_OCONUS") {
    base_plot <- plot_base(
      area_name = area_name,
      area_sf = area_sf,
      viz_cfg = viz_cfg
    )
  }

  # Build plot
  if (area_name == "CONUS_OCONUS") {
    # generate plots for each area
    area_gw_plots <- purrr::pmap(
      list(
        area_info_df[["name"]],
        area_info_df[["proj"]],
        area_info_df[["state_list"]],
        area_info_df[["scale_factor"]],
        extent_info,
        area_sf
      ),
      function(area_name, area_proj, area_state_list, area_scale_factor,
               extent_info, area_poly_sf) {
        # Generate appropriate scaling parameters for each area
        # _NOTE: this is a first stab at adjusting these for different areas. I
        # suspect we will also need to make some further adjustments_
        adj_scale_cfg <- scale_cfg |>
          mutate(
            max_vector_height =
              max_vector_height / area_scale_factor,
            mid_vector_height =
              mid_vector_height / area_scale_factor,
            min_vector_height =
              min_vector_height / area_scale_factor,
            max_vector_width =
              max_vector_width / area_scale_factor,
            mid_vector_width = max_vector_width * mid_factor,
            min_vector_width = max_vector_width * min_factor,
            normal_width = max_vector_width * min_factor
          )

        # Build base per-area
        area_base_plot <- NULL
        if (draw_base) {
          area_base_plot <- plot_base(
            area_name = area_name,
            area_sf = area_poly_sf,
            viz_cfg = viz_cfg
          )
        }

        p <- plot_gw(
          gw_parquet_file = gw_parquet_file,
          date_val = date_val,
          incl_date = FALSE,
          area_name = area_name,
          area_proj = area_proj,
          area_state_list = area_state_list,
          area_sf = area_poly_sf,
          palette = palette,
          viz_cfg = viz_cfg,
          scale_cfg = adj_scale_cfg,
          state_lookup = state_lookup,
          image_screen_type = image_screen_type,
          base_plot = area_base_plot,
          draw_base = draw_base,
          draw_symbols = draw_symbols
        ) +
          # make sure there is no expansion of extents
          scale_x_continuous(expand = c(0.00, 0.00)) +
          scale_y_continuous(expand = c(0.00, 0.00))
      }
    ) |>
      set_names(area_info_df[["name"]])

    # arrange plots
    extent_info <- set_names(extent_info, area_info_df[["name"]])
    gw_plot <- generate_landscape_condensed(
      area_info_df = area_info_df,
      areas_extents = extent_info,
      areas_plots = area_gw_plots,
      viz_config = viz_cfg,
      locator_map_png = if (is_foreground) NULL else locator_map_png,
      draw_labels = draw_labels,
      draw_scale_markers = draw_scale_markers
    )

    # DELETE LATER
    # for now, for testing, include date on final image
    incl_date <- layer_mode %in% c("full", "foreground")
    if (incl_date) {
      gw_plot <- gw_plot +
        draw_label(date_val,
          x = 0.99,
          y = 0.99,
          hjust = 1,
          vjust = 1,
          fontfamily = viz_cfg[["annotation_font"]],
          color = viz_cfg[["annotation_font_color"]],
          size = viz_cfg[["annotation_font_size"]]
        )
    } else {
      gw_plot <- gw_plot +
        draw_label(" ",
          x = 0.99,
          y = 0.99,
          hjust = 1,
          vjust = 1,
          fontfamily = viz_cfg[["annotation_font"]],
          color = viz_cfg[["annotation_font_color"]],
          size = viz_cfg[["annotation_font_size"]]
        )
    }
  } else {
    # DELETE LATER
    # for now, for testing, include date on final image
    incl_date <- layer_mode %in% c("full", "foreground")

    # Generate appropriate scaling parameters for each area
    # _NOTE: this is a first stab at adjusting these for different areas. I
    # suspect we will also need to make some further adjustments for mobile_
    if (image_screen_type == "mobile") {
      scale_cfg <- scale_cfg |>
        mutate(
          max_vector_height = max_vector_height * extent_info[["rel_height"]],
          mid_vector_height = mid_vector_height * extent_info[["rel_height"]],
          min_vector_height = min_vector_height * extent_info[["rel_height"]],
          max_vector_width = max_vector_width * extent_info[["rel_width"]],
          mid_vector_width = max_vector_width * mid_factor,
          min_vector_width = max_vector_width * min_factor,
          normal_width = max_vector_width * min_factor,
          max_peak_width = max_factor_mobile,
          mid_peak_width = max_factor_mobile * mid_factor,
          min_peak_width = max_factor_mobile * min_factor
        )
    }

    gw_plot <- plot_gw(
      gw_parquet_file = gw_parquet_file,
      date_val = date_val,
      incl_date = incl_date,
      area_name = area_name,
      area_proj = area_info_df[["proj"]],
      area_state_list = area_info_df[["state_list"]],
      area_sf = area_sf,
      palette = palette,
      viz_cfg = viz_cfg,
      scale_cfg = scale_cfg,
      state_lookup = state_lookup,
      image_screen_type = image_screen_type,
      base_plot = base_plot,
      draw_base = draw_base,
      draw_symbols = draw_symbols
    )

    # Make sure the plot extent is consistent, even if not drawing base map layers
    # Identify the center coordinates of the area that is plotted
    center_x <- 0.5 * (extent_info$x_min + extent_info$x_max)
    center_y <- 0.5 * (extent_info$y_min + extent_info$y_max)
    # Adjust the limits of the figure based on the area's x and y extent
    gw_plot <- gw_plot +
      ggplot2::coord_sf(
        xlim = c(
          center_x - 0.5 * extent_info$x_extent,
          center_x + 0.5 * extent_info$x_extent
        ),
        ylim = c(
          center_y - 0.5 * extent_info$y_extent,
          center_y + 0.5 * extent_info$y_extent
        )
      )

    # make space for ggfx shadow
    gw_plot <- gw_plot +
      scale_x_continuous(expand = c(0.05, 0.05)) +
      scale_y_continuous(expand = c(0.05, 0.05))

    # DELETE LATER
    # if not including date add placeholder title to ensure map placement on plot is the same
    if (!incl_date) {
      gw_plot <- gw_plot +
        labs(title = " ")
    }
  }

  # Export
  if (image_screen_type == "desktop") {
    export_width <- viz_cfg$width
    export_height <- viz_cfg$height
  } else if (image_screen_type == "mobile") {
    export_width <- viz_cfg$mobile_width
    export_height <- viz_cfg$mobile_height
  } else {
    stop(message("image_screen_type must be either 'desktop' or 'mobile'"))
  }

  bg_col <- if (transparent_bg) "transparent" else viz_cfg$bg_col

  if (output_format == "png") {
    ggsave(
      filename = out_path,
      plot = gw_plot,
      bg = bg_col,
      width = export_width,
      height = export_height,
      dpi = viz_cfg$dpi,
      units = viz_cfg$units
    )
  }

  if (output_format == "webp") {
    tmp_png <- tempfile(fileext = ".png")

    # save transparent png
    ggsave(
      filename = tmp_png,
      plot = gw_plot,
      bg = bg_col,
      width = export_width,
      height = export_height,
      dpi = viz_cfg$dpi,
      units = viz_cfg$units
    )

    # convert to WebP
    img <- magick::image_read(tmp_png)

    magick::image_write(
      img,
      path = out_path,
      format = "webp",
      compression = "WebP"
    )

    unlink(tmp_png)
  }
  return(out_path)
}

# Make legend marker with same dimensions for website build
#' Plot a single legend marker
#' @param gw_parquet_file gw_parquet_file Path to processed parquet file for one date
#' @param palette The color palette
#' @param viz_cfg Visual config (for dimensions/colors)
#' @param scale_cfg Scaling config (for linewidth/height)
#' @param out_path Path to save the PNGs
plot_gw_leg <- function(gw_parquet_file, conus_proj, palette, viz_cfg,
                        scale_cfg, out_path) {
  # Ensure directory exists
  if (!dir.exists(dirname(out_path))) dir.create(dirname(out_path), recursive = TRUE)

  # Read + project
  gw_sf <- arrow::read_parquet(gw_parquet_file) |>
    st_as_sf() |>
    st_set_crs(4326) |>
    st_transform(conus_proj) |>
    compute_peak_geometry(scale_cfg)

  # One row per category
  legend_rows <- gw_sf |>
    group_by(per_bin) |>
    slice_head(n = 1) |>
    ungroup()

  # Build each legend PNG
  purrr::map_chr(seq_len(nrow(legend_rows)), function(i) {
    leg_row <- legend_rows[i, ]
    # Assign values
    cat_name <- ifelse(is.na(leg_row$per_bin),
      "na_site",
      leg_row$per_bin
    )
    file_id <- janitor::make_clean_names(cat_name)
    file_path <- sprintf(out_path, file_id)
    is_na_cat <- is.na(leg_row$per_bin)
    order_val <- ifelse(is.na(leg_row$plotting_order), 0, leg_row$plotting_order)

    # Recenter the geometry based on the row's coordinates
    # But force 0s for NA site for marker
    if (is_na_cat) {
      leg_df <- leg_row |>
        as_tibble() |>
        mutate(x = 0, y = 0, x_start = 0, x_end = 0, y_end = 0)
    } else {
      leg_df <- leg_row |>
        as_tibble() |>
        mutate(
          x_start = x_start - x,
          x_end = x_end - x,
          y_end = y_end - y,
          x = 0,
          y = 0
        )
    }

    # Logic for peak fill width
    current_sf <- case_when(
      leg_df$plotting_order == 4 ~ scale_cfg$leg_scale_mult_factor,
      leg_df$plotting_order == 3 ~ scale_cfg$mid_factor * scale_cfg$leg_scale_mult_factor,
      leg_df$plotting_order == 2 ~ scale_cfg$min_factor * scale_cfg$leg_scale_mult_factor,
      TRUE ~ 0
    )

    p <- ggplot(leg_df) +
      # NA sites (X marker)
      {
        if (is_na_cat) {
          geom_point(
            aes(x = 0, y = 0),
            shape = 4,
            color = viz_cfg$na_sites_col,
            size = 2.5,
            stroke = 1.25
          )
        }
      } +
      # Normal lines (order 1)
      {
        if (!is_na_cat && order_val == 1) {
          geom_segment(
            aes(
              x = x_start, xend = x_end,
              y = y, yend = y_end,
              color = per_bin
            ),
            linewidth = 0.3
          )
        }
      } +
      # Peaks (order 2, 3, 4)
      {
        if (!is_na_cat && order_val > 1) {
          list(
            geom_link(
              aes(
                x = x, xend = x,
                y = y, yend = y_end,
                color = per_bin,
                mf = scale_cfg$max_factor,
                sf = current_sf,
                linewidth = after_stat(I((1 - index) * mf * sf * 1.2)),
                alpha = after_stat(I((0.99^index - 1) / (0.99 - 1)))
              )
            ),
            geom_segment(
              aes(
                x = x_start, xend = x,
                y = y, yend = y_end,
                color = per_bin
              ),
              linewidth = 0.15
            ),
            geom_segment(
              aes(
                x = x, xend = x_end,
                y = y_end, yend = y,
                color = per_bin
              ),
              linewidth = 0.15
            )
          )
        }
      } +
      scale_color_manual(
        values = palette,
        na.value = viz_cfg$na_sites_col
      ) +
      # expanded limits so "below" categories aren't cut off
      coord_cartesian(
        xlim = c(-scale_cfg$leg_xlim, scale_cfg$leg_xlim),
        ylim = c(-scale_cfg$leg_ylim, scale_cfg$leg_ylim)
      ) +
      theme_void() +
      theme(legend.position = "none")

    ggsave(
      filename = file_path,
      plot = p,
      width = viz_cfg$leg_width,
      height = viz_cfg$leg_height,
      dpi = viz_cfg$dpi,
      units = "px"
    )
  })
}

#' Create triangle polygon coordinates for groundwater peaks
#'
#' Transforms site level peak dimensions into a long-format coordinate table
#' suitable for geom_polygon.
#'
#' @param df A data frame containing monitoring_location_id, x, y, x_start, x_end, and y_end.
#' @param expand Numeric factor to scale the triangle size beyond its base height and width.
#'
#' @return A data frame with three rows per site, containing x_poly and y_poly.
make_peak_polygon <- function(df, expand = 0.06) {
  df |>
    uncount(3) |>
    group_by(monitoring_location_id) |>
    mutate(
      vertex = row_number(),
      x_poly = case_when(
        vertex == 1 ~ x_start - expand * x_dif / 2,
        vertex == 2 ~ x,
        vertex == 3 ~ x_end + expand * x_dif / 2
      ),
      y_poly = case_when(
        vertex == 1 ~ y,
        vertex == 2 ~ y_end + expand * y_dif / 2,
        vertex == 3 ~ y
      )
    ) |>
    ungroup()
}

#' Compute peak geometry for projected groundwater data
#'
#' @param gw_sf An sf object containing groundwater data with
#'   `plotting_order` and `direction` columns.
#' @param scale_cfg Scaling config.
#' @return An sf object with additional plotting geometry columns
compute_peak_geometry <- function(gw_sf, scale_cfg) {
  # Extract projected coordinates
  coords <- sf::st_coordinates(gw_sf)

  gw_sf |>
    dplyr::mutate(
      x = coords[, 1],
      y = coords[, 2],
      x_dif = case_when(
        plotting_order == 1 ~ scale_cfg$normal_width,
        plotting_order == 2 ~ scale_cfg$min_vector_width,
        plotting_order == 3 ~ scale_cfg$mid_vector_width,
        plotting_order == 4 ~ scale_cfg$max_vector_width
      ),
      x_start = x - x_dif / 2,
      x_end = x + x_dif / 2,
      y_dif = case_when(
        plotting_order == 1 ~ 0,
        plotting_order == 2 ~ scale_cfg$min_vector_height * direction,
        plotting_order == 3 ~ scale_cfg$mid_vector_height * direction,
        plotting_order == 4 ~ scale_cfg$max_vector_height * direction
      ),
      y_end = y + y_dif,
      peak_width = case_when(
        plotting_order == 2 ~ scale_cfg$min_peak_width,
        plotting_order == 3 ~ scale_cfg$mid_peak_width,
        plotting_order == 4 ~ scale_cfg$max_peak_width,
        TRUE ~ NA_real_
      )
    ) |>
    dplyr::arrange(plotting_order)
}

#' Build and save a static groundwater PNG for one date
#'
#' Reads existing background and foreground images, adds static elements (logo, legend),
#' and saves the formatted static image.
#'
#' @param gw_bkgd_img Path for backgroup webp image.
#' @param gw_frgd_img Path for foreground webp image.
#' @param date Date for which the groundwater image was generated.
#' @param logo_path Path to USGS logo image.
#' @param legend_path Path to legend image.
#' @param viz_cfg Visualization configuration.
#' @param image_screen_type Image type (e.g., "desktop" or "mobile").
#' @param area_name Name of area being plotted (e.g., "CONUS").
#' @param output_template Filename template used to build output path.
#'
#' @return Character string path to saved PNG.
plot_gw_static_png <- function(gw_bkgd_img, gw_frgd_img, date, logo_path, legend_path,
                               viz_cfg, image_screen_type, area_name,
                               output_template) {
  date_val <- as.character(date)
  out_path <- sprintf(
    output_template, paste0("static-", image_screen_type),
    area_name, date_val
  )

  message(sprintf(
    "Building static image from %s & %s to make %s",
    gw_bkgd_img,
    gw_frgd_img,
    out_path
  ))

  if (!dir.exists(dirname(out_path))) {
    dir.create(dirname(out_path), recursive = TRUE)
  }

  # read in webp images
  bkgd_img <- magick::image_read(gw_bkgd_img)
  frgd_img <- magick::image_read(gw_frgd_img)

  usgs_logo <- magick::image_read(logo_path) |>
    magick::image_colorize(100, "black")

  legend_img <- magick::image_read(legend_path)

  canvas <- grid::rectGrob(
    x = 0, y = 0,
    width = viz_cfg$width, height = viz_cfg$height,
    gp = grid::gpar(
      fill = viz_cfg$bg_col,
      alpha = 1, col = viz_cfg$bg_col
    )
  )

  p <- ggdraw(
    ylim = c(0, 1),
    xlim = c(0, 1)
  ) +
    # a background
    draw_grob(canvas,
      x = 0, y = 1,
      height = 8, width = 8,
      hjust = 0, vjust = 1
    ) +
    # background image
    draw_image(bkgd_img,
      x = 0,
      y = 0,
      width = 1,
      height = 1
    ) +
    # foreground image
    draw_image(frgd_img,
      x = 0,
      y = 0,
      width = 1,
      height = 1
    ) +
    # Mock image legend
    draw_image(legend_img,
      x = 0.9,
      y = 1.04,
      scale = 0.32,
      height = 1,
      hjust = 1,
      vjust = 1,
      halign = 1,
      valign = 1
    ) +
    # Add logo
    draw_image(usgs_logo,
      x = 0.98,
      y = 0.024,
      width = 0.1,
      hjust = 1, vjust = 0,
      halign = 0, valign = 0
    ) +
    # Add date
    draw_label(format(date, "%B%e, %Y"),
      x = 0.01,
      y = 0.98,
      hjust = 0,
      vjust = 1,
      fontfamily = viz_cfg[["date_font"]],
      color = viz_cfg[["date_font_color"]],
      size = viz_cfg[["date_font_size"]]
    )

  ggsave(
    filename = out_path,
    plot = p,
    width = viz_cfg$width,
    height = viz_cfg$height,
    dpi = viz_cfg$dpi,
    units = viz_cfg$units,
    bg = viz_cfg$bg_col
  )

  return(out_path)
}
