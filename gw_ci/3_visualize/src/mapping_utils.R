#' Render and save a groundwater condition frame
#'
#' Builds a groundwater peak visualization for a single timestep and saves
#' the resulting plot to disk.
#'
#' @param gw_sf An sf object containing processed groundwater data for one date.
#' @param date A Date corresponding to the frame timestep.
#' @param conus_states_sf An sf object of CONUS state boundaries.
#' @param palette Named vector of colors for groundwater condition bins.
#' @param viz_cfg A list or tibble of visualization configuration values.
#' @param scale_cfg A list or tibble of scaling parameters for peak geometry.
#' @param out_path File path where the rendered frame will be saved.
#'
#' @return A character string giving the path to the saved image file.
plot_gw_frame <- function(gw_sf, date,
                          conus_states_sf,
                          palette, viz_cfg,
                          scale_cfg, out_path) {

  # Ensure the directory exists so ggsave doesn't error
  if(!dir.exists(dirname(out_path))) dir.create(dirname(out_path), recursive = TRUE)

  plot_date <- gw_sf |>
    as_tibble() |>
    pull(Date) |>
    unique() |>
    head(1)

  p <- ggplot() +
    ggfx::with_shadow(
      geom_sf(
        data = conus_states_sf,
        fill = viz_cfg$bg_col,
        color = viz_cfg$conus_states_col,
        size = 0.2
      ),
      colour = viz_cfg$ggfx_col,
      sigma = 12
    ) +
    # NA sites
    geom_sf(
      data = dplyr::filter(gw_sf, is.na(per)),
      color = viz_cfg$na_sites_col,
      size = 0.3,
      stroke = 0
    ) +
    # plotting order 1, lines
    geom_segment(
      data = dplyr::filter(gw_sf, plotting_order == 1),
      aes(
        x = x_start,
        xend = x_end,
        y = y,
        yend = y_end,
        color = per_bin
      ),
      linewidth = 0.08
    ) +
    # plotting order 2, peaks and segments
    geom_link(
      data = dplyr::filter(gw_sf, plotting_order == 2),
      aes(
        x = x, xend = x,
        y = y, yend = y_end,
        color = per_bin,
        linewidth = after_stat(I((1 - index) * scale_cfg$max_factor *  scale_cfg$min_factor)),
        # alpha = after_stat(I(index)), # linear gradient
        alpha = after_stat(I((0.2^index - 1) / (0.2 - 1))) # non-linear gradient
      )
    ) +
    geom_segment(
      data = dplyr::filter(gw_sf, plotting_order == 2),
      aes(x = x_start, xend = x, y = y, yend = y_end, color = per_bin),
      linewidth = 0.08
    ) +
    geom_segment(
      data = dplyr::filter(gw_sf, plotting_order == 2),
      aes(x = x, xend = x_end, y = y_end, yend = y, color = per_bin),
      linewidth = 0.08
    ) +
    # plotting order 3, peaks and segments
    geom_link(
      data = dplyr::filter(gw_sf, plotting_order == 3),
      aes(
        x = x, xend = x,
        y = y, yend = y_end,
        color = per_bin,
        linewidth = after_stat(I((1 - index) * scale_cfg$max_factor *  scale_cfg$mid_factor)),
        # alpha = after_stat(I(index)), # linear gradient
        alpha = after_stat(I((0.2^index - 1) / (0.2 - 1))) # non-linear gradient
      )
    ) +
    geom_segment(
      data = dplyr::filter(gw_sf, plotting_order == 3),
      aes(x = x_start, xend = x, y = y, yend = y_end, color = per_bin),
      linewidth = 0.08
    ) +
    geom_segment(
      data = dplyr::filter(gw_sf, plotting_order == 3),
      aes(x = x, xend = x_end, y = y_end, yend = y, color = per_bin),
      linewidth = 0.08
    ) +
    # plotting order 4, peaks and segments
    geom_link(
      data = dplyr::filter(gw_sf, plotting_order == 4),
      aes(
        x = x, xend = x,
        y = y, yend = y_end,
        color = per_bin,
        linewidth = after_stat(I((1 - index) * scale_cfg$max_factor)),
        # alpha = after_stat(I(index)), # linear gradient
        alpha = after_stat(I((0.2^index - 1) / (0.2 - 1))) # non-linear gradient
      )
    ) +
    geom_segment(
      data = dplyr::filter(gw_sf, plotting_order == 4),
      aes(x = x_start, xend = x, y = y, yend = y_end, color = per_bin),
      linewidth = 0.08
    ) +
    geom_segment(
      data = dplyr::filter(gw_sf, plotting_order == 4),
      aes(x = x, xend = x_end, y = y_end, yend = y, color = per_bin),
      linewidth = 0.08
    ) +
    # scales
    scale_color_manual(values = palette) +
    scale_x_continuous(expand = c(0.06, 0.06)) +
    scale_y_continuous(expand = c(0.06, 0.06)) +
    theme_void() +
    theme(legend.position = "none")
  # +
  #   ggtitle(plot_date)


  ggsave(
    filename = out_path,
    plot = p,
    width = viz_cfg$width,
    height = viz_cfg$height,
    dpi = viz_cfg$dpi,
    bg = viz_cfg$bg_col,
    units = viz_cfg$units
  )

  return(out_path)
}

# Make legend marker with same dimensions for website build
#' Plot a single legend marker
#' @param category The name of the category (ex, "Much above")
#' @param palette The color palette
#' @param viz_cfg Visual config (for dimensions/colors)
#' @param scale_cfg Scaling config (for linewidth/height)
#' @param out_path Path to save the PNGs
plot_gw_leg <- function(category, palette, viz_cfg, scale_cfg, out_path) {

  if(!dir.exists(dirname(out_path))) dir.create(dirname(out_path), recursive = TRUE)

  # Logic for peak height and direction
  plotting_order_val <- case_when(
    category == "Extremely above" ~ 4,
    category == "Much above" ~ 3,
    category == "Above normal" ~ 2,
    category == "Normal" ~ 1,
    category == "Below normal" ~ 2,
    category == "Much below" ~ 3,
    category == "Extremely below" ~ 4,
    TRUE ~ NA_real_
  )
  # Apply directionality for above vs below
  direction_val <- ifelse(category %in% c("Normal", "Above normal",
                                          "Much above", "Extremely above"),
                          1, -1)

  # Logic for peak dimensions
  x_dif_val <- case_when(
    plotting_order_val == 1 ~ scale_cfg$normal_width,
    plotting_order_val == 2 ~ scale_cfg$min_vector_width,
    plotting_order_val == 3 ~ scale_cfg$mid_vector_width,
    plotting_order_val == 4 ~ scale_cfg$max_vector_width,
    TRUE ~ 0
  )

  y_dif_val <- case_when(
    plotting_order_val == 1 ~ 0,
    plotting_order_val == 2 ~ scale_cfg$min_vector_height * direction_val,
    plotting_order_val == 3 ~ scale_cfg$mid_vector_height * direction_val,
    plotting_order_val == 4 ~ scale_cfg$max_vector_height * direction_val,
    TRUE ~ 0
  )

  # Use smaller sizes for the NA dot and normal line
  na_dot_size <- ifelse(is.na(category), 1.5, 0)
  norm_line_width <- ifelse(!is.na(category) && plotting_order_val == 1, 0.2, 0)

  leg_df <- tibble(
    x = 0, y = 0,
    x_start = - (x_dif_val / 2),
    x_end = (x_dif_val / 2),
    y_end = y_dif_val,
    per_bin = category,
    plotting_order = plotting_order_val
  )

  # scaling factor for the fill
  current_sf <- case_when(
    plotting_order_val == 4 ~ 1,
    plotting_order_val == 3 ~ scale_cfg$mid_factor,
    plotting_order_val == 2 ~ scale_cfg$min_factor,
    TRUE ~ 0
  )

  p <- ggplot(leg_df) +
    # NA sites
    {if(is.na(category)) geom_point(aes(x = 0, y = 0),
                                    color = viz_cfg$na_sites_col,
                                    size = na_dot_size)} +
    # Normal lines (order 1)
    {if(!is.na(category) && plotting_order_val == 1)
      geom_segment(aes(x = x_start, xend = x_end, y = y, yend = y_end,
                       color = per_bin), linewidth = norm_line_width)} +
    # Peaks (order 2, 3, 4)
    {if(!is.na(category) && plotting_order_val > 1) list(
      geom_link(aes(
        x = x, xend = x, y = y, yend = y_end, color = per_bin,
        mf = scale_cfg$max_factor,
        sf = current_sf,
        linewidth = after_stat(I((1 - index) * mf * sf * 1.2)),
        alpha = after_stat(I((0.99^index - 1) / (0.99 - 1)))
      )
      # ,
      # n = 100
      ),
      geom_segment(aes(x = x_start, xend = x, y = y, yend = y_end,
                       color = per_bin), linewidth = 0.15),
      geom_segment(aes(x = x, xend = x_end, y = y_end, yend = y,
                       color = per_bin), linewidth = 0.15)
    )} +
    scale_color_manual(values = palette, na.value = viz_cfg$na_sites_col) +
    # expanded limits so "below" categories aren't cut off
    coord_cartesian(xlim = c(-80000, 80000), ylim = c(-70000, 70000)) +
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
