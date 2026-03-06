#' Build and save a CONUS groundwater png for one date
#'
#' Reads processed parquet data, filters to CONUS, reprojects spatial data,
#' renders the groundwater map, and saves the png
#'
#' @param gw_parquet_file Path to processed parquet file for one date.
#' @param date Date for which gw data are being plotted.
#' @param conus_states sf of CONUS states.
#' @param conus_inner_states_sf sf of inner state boundaries.
#' @param conus_outer_states_sf sf of outer CONUS boundary.
#' @param palette Named color vector.
#' @param viz_cfg Visualization config.
#' @param scale_cfg Scaling config.
#' @param state_lookup State lookup table.
#' @param oconus_abbr Character vector of OCONUS state abbreviations.
#' @param conus_proj crs for CONUS projection.
#' @param out_path Filename template containing `%s` for date.
#'
#' @return Character string path to saved PNG.
plot_conus_gw_pngs <- function(gw_parquet_file, date, conus_states,
                               conus_inner_states_sf, conus_outer_states_sf,
                               palette, viz_cfg, scale_cfg, state_lookup,
                               oconus_abbr, conus_proj, output_template) {
  
  date_val <- as.character(date)
  out_path <- sprintf(output_template, date_val)
  
  message(sprintf(
    "read in %s and plot CONUS map for %s, saving as %s",
    gw_parquet_file,
    date_val,
    out_path
  ))
  
  # Ensure the directory exists so ggsave doesn't error
  if(!dir.exists(dirname(out_path))) dir.create(dirname(out_path), recursive = TRUE)
  
  # Read and convert to sf, join states, drop oconus
  gw_sf <- arrow::read_parquet(gw_parquet_file) |>
    st_as_sf() |> 
    # Must set CRS to then transform from
    st_set_crs(sf::st_crs("EPSG:4326")) |> 
    st_transform(conus_proj) |> 
    left_join(state_lookup, by = c("state_name" = "state_name_std")) |>
    filter(
      !state_abbr %in% oconus_abbr,
      state_abbr != "MH"
      ) |> 
    # add in peaks computing fxn after transformation 
    compute_peak_geometry(scale_cfg)
  
  # Sorting by plotting order and latitude (y) to help with overplotted areas
  gw_plot_order <- gw_sf |> 
    arrange(plotting_order, desc(y))
  
  p <- ggplot() +
    # Map shadows
    ggfx::with_shadow(
      # Entire states polygons for shadow effect
      geom_sf(
        data = conus_states,
        fill = viz_cfg$bg_col,
        color = NA
      ),
      colour = viz_cfg$ggfx_col,
      x_offset = 0,
      y_offset = 0,
      sigma = 12
    ) +
    # Internal state borders
    geom_sf(
      data = conus_inner_states_sf,
      color = viz_cfg$conus_states_col, 
      linewidth = 0.2,
      fill = NA
    ) +
    # Minimal external boundary
    geom_sf(
      data = conus_outer_states_sf,
      color = viz_cfg$bg_col, 
      linewidth = 0.05,
      fill = NA
    ) +
    # NA sites
    geom_sf(
      data = filter(gw_plot_order, is.na(per_bin)),
      color = viz_cfg$na_sites_col,
      shape = 4,
      size = 0.4,
      stroke = 0.2
    ) + 
    # Plotting order 1: horizontal lines
    geom_segment(
      data = filter(gw_plot_order, plotting_order == 1),
      aes(
        x = x_start,
        xend = x_end,
        y = y,
        yend = y_end,
        color = per_bin
      ),
      linewidth = 0.125
    ) 
  
  # Identify sites orders 2 through 4
  sites_order_2_to_4 <- gw_plot_order |>
    filter(plotting_order %in% 2:4) |>
    pull(monitoring_location_id) |>
    unique()
  
  # For each site, plot mask, gradient, and border
  site_plots <- purrr::map(sites_order_2_to_4, function(site) {
    site_gw <- filter(gw_plot_order, monitoring_location_id == site)
    
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
        alpha = after_stat(I((0.2^index - 1) / (0.2 - 1)))
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
        alpha = after_stat(I((0.2^index - 1) / (0.2 - 1)))
      )
    )
    
    # Layer 3: border
    border1 <- geom_segment(
      data = site_gw,
      aes(
        x = x_start,
        xend = x,
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
    
    return(c(mask, gradient, border1, border2))
  })
  
  p <- p +
    site_plots
  
  p <- p +
    # Scales and themes
    scale_color_manual(values = palette) +
    scale_x_continuous(expand = c(0.06, 0.06)) +
    scale_y_continuous(expand = c(0.06, 0.06)) +
    theme_void() +
    theme(legend.position = "none") +
    labs(title = date_val)
  
  # Export
  ggsave(
    filename = out_path,
    plot = p,
    width = viz_cfg$width, height = viz_cfg$height,
    dpi = viz_cfg$dpi, bg = viz_cfg$bg_col, units = viz_cfg$units
  )
  
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
  if(!dir.exists(dirname(out_path))) dir.create(dirname(out_path), recursive = TRUE)
  
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
                       leg_row$per_bin)
    file_id  <- janitor::make_clean_names(cat_name)
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
      {if (is_na_cat)
        geom_point(
          aes(x = 0, y = 0),
          shape = 4,
          color = viz_cfg$na_sites_col,
          size = 2.5,
          stroke = 1.25
        )} +
      # Normal lines (order 1)
      {if (!is_na_cat && order_val == 1)
        geom_segment(
          aes(
            x = x_start, xend = x_end,
            y = y, yend = y_end,
            color = per_bin
          ),
          linewidth = 0.3
        )} +
      # Peaks (order 2, 3, 4)
      {if (!is_na_cat && order_val > 1)
        list(
          geom_link(
            aes(
              x = x, xend = x,
              y = y, yend = y_end,
              color = per_bin,
              mf = scale_cfg$max_factor,
              sf = current_sf,
              linewidth = after_stat(I((1 - index) * mf * sf*1.2)),
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
          )} +
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
      units = "px",
      bg = viz_cfg$bg_col
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
