#' Render and save a groundwater condition frame
#'
#' Builds a groundwater peak visualization for a single timestep and saves
#' the resulting plot to disk.
#'
#' @param gw_sf An sf object containing processed groundwater data for one date.
#' @param date A Date corresponding to the frame timestep.
#' @param conus_states An sf object of CONUS inner and outer state boundaries.
#' @param conus_inner_states_sf An sf object of CONUS innner state boundaries.
#' @param conus_inner_states_sf An sf object of CONUS outline boundary.
#' @param palette Named vector of colors for groundwater condition bins.
#' @param viz_cfg A list or tibble of visualization configuration values.
#' @param scale_cfg A list or tibble of scaling parameters for peak geometry.
#' @param out_path File path where the rendered frame will be saved.
#'
#' @return A character string giving the path to the saved image file.
#' Render and save a groundwater condition frame
plot_gw_frame <- function(gw_sf, date,
                          conus_states,
                          conus_inner_states_sf,
                          conus_outer_states_sf,
                          palette, viz_cfg,
                          scale_cfg, out_path) {
  
  # Ensure the directory exists so ggsave doesn't error
  if(!dir.exists(dirname(out_path))) dir.create(dirname(out_path), recursive = TRUE)
  
  # Sorting by plotting order and latitude (y) to help with overplotted areas
  gw_plot_order <- gw_sf |> 
    arrange(plotting_order, desc(y))
  
  # Prepare peak data and generate masking polygons with metadata
  white_peaks <- gw_plot_order |> 
    filter(plotting_order %in% 2:4) |> 
    make_peak_polygon(expand = 0.07) |> 
    # Match the sorting of main data
    arrange(plotting_order, desc(y_poly))
  
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
      data = filter(gw_plot_order, is.na(per)),
      color = viz_cfg$na_sites_col,
      shape = 4,
      size = 0.4,
      stroke = 0.2
    ) + 
    # Plotting order 1: horizontal lines
    geom_segment(
      data = filter(gw_plot_order, plotting_order == 1),
      aes(
        x = x - scale_cfg$normal_width / 2,
        xend = x + scale_cfg$normal_width / 2,
        y = y,
        yend = y_end,
        color = per_bin
      ),
      linewidth = 0.125
    ) 
  
  # Identify sites orders 2 through 4
  sites_order_2_to_4 <- gw_plot_order |>
    filter(plotting_order %in% 2:4) |>
    pull(site_no) |>
    unique()
  
  # For each site, plot mask, gradient, and border
  site_plots <- purrr::map(sites_order_2_to_4, function(site) {
    site_gw <- filter(gw_plot_order, site_no == site)
    
    # Layer 1: mask
    mask <- geom_link(
      data = site_gw,
      aes(
        x = x,
        xend = x,
        y = y,
        yend = y_end,
        group = site_no,
        peak_width = peak_width,
        linewidth = after_stat(I((1 - index) * scale_cfg$max_factor * peak_width)),
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
        group = site_no,
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
    labs(title = date)
  
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
#'@param leg_row Single row tibble/sf object for a specific category
#' @param palette The color palette
#' @param viz_cfg Visual config (for dimensions/colors)
#' @param scale_cfg Scaling config (for linewidth/height)
#' @param out_path Path to save the PNGs
plot_gw_leg <- function(leg_row, palette, viz_cfg, scale_cfg, out_path) {

  if(!dir.exists(dirname(out_path))) dir.create(dirname(out_path), recursive = TRUE)
  
  # Assign values
  cat_val   <- leg_row$per_bin
  is_na_cat <- is.na(cat_val)
  order_val <- ifelse(is.na(leg_row$plotting_order), 0, leg_row$plotting_order)
  
  # Recenter the geometry based on the row's coordinates
  # But force 0s for NA site for marker
  if (is_na_cat) {
    # Force 0s for NA site so ggplot has valid coordinates to plot
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
  
  # Use smaller sizes for the NA dot and normal line
  na_dot_size     <- ifelse(is_na_cat, 2, 0)
  norm_line_width <- ifelse(!is_na_cat && order_val == 1, 0.3, 0)
  
  p <- ggplot(leg_df) +
    # NA sites
    {if (is_na_cat) 
      geom_point(
        aes(x = 0, y = 0),
        color = viz_cfg$na_sites_col,
        size  = na_dot_size
      )} +
    # Normal lines (order 1)
    {if (!is.na(is_na_cat) && order_val == 1) 
      geom_segment(
        aes(
          x = x_start, xend = x_end,
          y = y, yend = y_end,
          color = per_bin
          ),
        linewidth = norm_line_width
        )} +
    # Peaks (order 2, 3, 4)
    {if (!is.na(is_na_cat) && order_val > 1) 
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
        )} +
    scale_color_manual(values = palette, na.value = viz_cfg$na_sites_col) +
    # expanded limits so "below" categories aren't cut off
    coord_cartesian(xlim = c(-scale_cfg$leg_xlim, scale_cfg$leg_xlim), 
                    ylim = c(-scale_cfg$leg_ylim, scale_cfg$leg_ylim)) +
    theme_void() +
    theme(legend.position = "none")
  
  ggsave(
    filename = out_path,
    plot = p,
    width = viz_cfg$leg_width,
    height = viz_cfg$leg_height,
    dpi = viz_cfg$dpi,
    units = "px",
    bg = viz_cfg$bg_col
  )

  return(out_path)
}

#' Create triangle polygon coordinates for groundwater peaks
#' 
#' Transforms site level peak dimensions into a long-format coordinate table 
#' suitable for geom_polygon.
#'
#' @param df A data frame containing site_no, x, y, x_start, x_end, and y_end.
#' @param expand Numeric factor to scale the triangle size beyond its base height and width.
#' 
#' @return A data frame with three rows per site, containing x_poly and y_poly.
make_peak_polygon <- function(df, expand = 0.06) {
  df |>
    uncount(3) |>   
    group_by(site_no) |>
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
