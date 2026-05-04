# https://yjunechoe.github.io/posts/2021-06-24-setting-up-and-debugging-custom-fonts/
#' Get all variants of a font
#'
#' @param family font family for which to get all variants
#' @param silent logical - display message with extracted variants or no
#'
#' @return Nothing - simply registers font variants with system
#' 
font_hoist <- function(family, silent = FALSE) {
  font_specs <- systemfonts::system_fonts() |>
    dplyr::filter(family == .env[["family"]]) |>
    dplyr::mutate(family = paste(.data[["family"]], .data[["style"]])) |>
    dplyr::select(plain = .data[["path"]], name = .data[["family"]])
  
  purrr::pwalk(as.list(font_specs), systemfonts::register_font)
  
  if (!silent)  message(paste0("Hoisted ", nrow(font_specs), " variants:\n",
                               paste(font_specs[["name"]], collapse = "\n")))
}

#' Adjust plot limits based on area extent, area scale factor, and reference scale
#'
#' @param raw_plot the input plot for a single area, without adjusted x and y 
#' coord_sf limits
#' @param fig_dims the x, y, width, and height parameters for how the plot will
#' eventually be placed in the final figure
#' @param extent_info spatial extent information for the plotted area
#' @param reference_scale the m/pixels reference at which CONUS will be plotted
#' @param scale_factor the scale factor relative to CONUS scale for plotting
#' this area
#' @param viz_config Visualization config. Contains information on the
#' width and height of the final plot, in pixels
#'
#' @return The input plot with limits adjusted to account for scaling relative
#' to CONUS, effectively zooming in or out on the `raw_plot`
#' 
adjust_plot_lims <- function(raw_plot, fig_dims, extent_info, reference_scale, 
                             scale_factor, viz_config) {
  # Pull the figure width and height, in pixels
  fig_width <- viz_config$width*fig_dims[["width"]]
  fig_height <- viz_config$height*fig_dims[["height"]]
  # Identify the center coordinates of the area that is plotted
  center_x <- 0.5 * (extent_info$x_min + extent_info$x_max)
  center_y <- 0.5 * (extent_info$y_min + extent_info$y_max)
  # Determine what the extent of the figure should be, based on the extent of
  # the area and the scale at which it will be shown, relative to CONUS
  fig_x_extent <- reference_scale * fig_width / scale_factor
  fig_y_extent <- reference_scale * fig_height / scale_factor
  # Adjust the limits of the figure based on the computed x and y extent
  adj_plot <- raw_plot +
    ggplot2::coord_sf(
      xlim = c(
        center_x - 0.5 * fig_x_extent,
        center_x + 0.5 * fig_x_extent 
      ),
      ylim = c(
        center_y - 0.5 * fig_y_extent,
        center_y + 0.5 * fig_y_extent 
      )
    )
  return(adj_plot)
}

#' Place plots for CONUS + OCONUS areas into a single condensed landscape layout
#'
#' @param area_info_df dataframe with information about the area for which to 
#' plot gw data, including the name of area, the scale factor to use for the area,
#' and the list of placement parameters for placing the area on the final plot
#' @param areas_extents a list with spatial extent information for each area
#' @param areas_plots a list with plots for each area
#' @param locator_map_png  a png of the locator map
#' @param viz_config Visualization config. Contains information on the
#' width and height of the final plot, in pixels, visual parameters like line
#' color and width, and the width of the ggfx shadow effect
#' @param draw_labels Logical; if TRUE, draw area labels (e.g., "Conterminous United States")
#' @param draw_scale_markers Logical; if TRUE, draw scale marker corner lines for each area
#'
#'
#' @return A final formatted plot with CONUS and OCONUS areas laid out as well
#' as a locator map
#' 
generate_landscape_condensed <- function(area_info_df, areas_extents, 
                                         areas_plots, viz_config,
                                         locator_map_png = NULL,
                                         draw_labels = TRUE,
                                         draw_scale_markers = TRUE ) {
  # extract key variables  
  placement_params <- area_info_df[["placement_params"]] |>
    set_names(area_info_df[["name"]])
  scale_factors <- area_info_df[["scale_factor"]] |>
    set_names(area_info_df[["name"]])

  # Build reference scale (m/pixel) based on CONUS x extent and plotted width
  conus_fig_width <- viz_config$width*placement_params[["CONUS"]][["width"]]
  reference_length <- areas_extents$CONUS$x_extent
  # account for the Gaussian blur, so that it doesn't get cut off
  # viz_config[["ggfx_sigma"]] = the SD of the Gaussian blur
  # 95% of the Gaussian kernel should fall within +- 2 SD
  # 99% within +- 3 SD
  # remaining width = width that actual conus map will take up
  reference_scale <- reference_length/(conus_fig_width - 4*viz_config[["ggfx_sigma"]] ) # m per pixel
  
  # adjust limits for all plots based on reference scale and scale factor for 
  # each area, effectively zooming in or out based on scale factor
  adjusted_area_plots <- purrr::pmap(
    list(area_info_df[["scale_factor"]],
         area_info_df[["placement_params"]],
         areas_plots, 
         areas_extents),
    function(area_scale_factor, area_placement_params, area_plot,
             extent_info) {
      adjust_plot_lims(
        raw_plot = area_plot, 
        fig_dims = unlist(area_placement_params), 
        extent_info = extent_info, 
        reference_scale = reference_scale, 
        scale_factor = area_scale_factor, 
        viz_config = viz_config
      )
    }) |>
    set_names(area_info_df[["name"]])
  
  # For font use approach outlined here: # https://yjunechoe.github.io/posts/2021-06-24-setting-up-and-debugging-custom-fonts/
  # CHECK IF HAVE FONT IN SYSTEM
  system_fonts <- systemfonts::system_fonts() |> pull(family)
  if (!viz_config[["plot_font"]] %in% system_fonts) {
    stop("You must install the Source Sans 3 font to your system. Download all variants of the font from https://fonts.google.com/specimen/Source+Sans+3?query=source+sans")
  }
  
  # get all font styles
  font_hoist(viz_config[["plot_font"]], silent = TRUE)
  
  # # If want to check style names
  # # Grab the newly registered font families
  # source_sans_3_styles <- systemfonts::registry_fonts() %>%
  #   filter(str_detect(family, viz_config[["plot_font"]]), style == "Regular") %>%
  #   pull(family)
  
  # build final plot
  canvas <- grid::rectGrob(
    x = 0, y = 0, 
    width = viz_config[["width"]], height = viz_config[["height"]],
    gp = grid::gpar(fill = NA, col = NA)
  )
  
  # set up scaling parameters and visual parameters for scale markers
  plot_width_cowplot_scalar <- viz_config[["height"]] / viz_config[["width"]]
  scale_base_height <- 0.03
  scale_base_width <- scale_base_height * plot_width_cowplot_scalar
  scale_buffer_vertical <- 0.01
  scale_buffer_horizontal <- scale_buffer_vertical * plot_width_cowplot_scalar
  
  plot <- ggdraw(ylim = c(0,1), 
                 xlim = c(0,1)) +
    # a background
    draw_grob(
      canvas,
      x = 0, 
      y = 1,
      height = viz_config[["height"]], 
      width = viz_config[["width"]],
      hjust = 0, 
      vjust = 1)
  
  # place all plots
  drawn_plots <- purrr::map(area_info_df[["name"]], function(area_name) {
      draw_plot(
        adjusted_area_plots[[area_name]] + theme(legend.position = 'none'),
        x = placement_params[[area_name]][["x"]],
        y = placement_params[[area_name]][["y"]],
        width = placement_params[[area_name]][["width"]],
        height = placement_params[[area_name]][["height"]],
        hjust = 0,
        vjust = 0)
  })
  # place all scale markers
  drawn_scale_markers <- purrr::map(area_info_df[["name"]], function(area_name) {
    if (area_name == "AK") {
      # lower right
      draw_line(
        x = c(
          placement_params[[area_name]][["x"]] + 
            placement_params[[area_name]][["width"]] -
            scale_base_width*scale_factors[[area_name]],
          placement_params[[area_name]][["x"]] + 
            placement_params[[area_name]][["width"]],
          placement_params[[area_name]][["x"]] + 
            placement_params[[area_name]][["width"]]),
        y = c(
          placement_params[[area_name]][["y"]],
          placement_params[[area_name]][["y"]],
          placement_params[[area_name]][["y"]] + 
            scale_base_height*scale_factors[[area_name]]),
        color = viz_config[["scale_line_color"]],
        linewidth = viz_config[["scale_lwd"]],
        linetype = 'solid'
      )
    } else {
      # upper left
      draw_line(
        x = c(
          placement_params[[area_name]][["x"]],
          placement_params[[area_name]][["x"]],
          placement_params[[area_name]][["x"]] +
            scale_base_width*scale_factors[[area_name]]),
        y = c(
          placement_params[[area_name]][["y"]] + 
            placement_params[[area_name]][["height"]] -
            scale_base_height*scale_factors[[area_name]],
          placement_params[[area_name]][["y"]] + 
            placement_params[[area_name]][["height"]],
          placement_params[[area_name]][["y"]] + 
            placement_params[[area_name]][["height"]]),
        color = viz_config[["scale_line_color"]],
        linewidth = viz_config[["scale_lwd"]],
        linetype = 'solid'
      )
    }
  })
  # place all labels
  drawn_labels <- purrr::map2(
    area_info_df[["name"]], area_info_df[["full_name"]], 
    function(area_name, area_full_name) {
      if (area_name == "AK") {
        # Lower right
        draw_label(
          stringr::str_glue("{area_full_name} {scale_factors[[area_name]]}x"),
          x = placement_params[[area_name]][["x"]] + 
            placement_params[[area_name]][["width"]] -
            scale_buffer_horizontal,
          y = placement_params[[area_name]][["y"]] +
            scale_buffer_vertical,
          hjust = 1,
          vjust = 0,
          fontfamily = viz_config[["scale_font"]],
          color = viz_config[["scale_font_color"]],
          size = viz_config[["scale_font_size"]]
        )
      } else if (area_name == "GU_MP") {
        draw_label(
          stringr::str_glue("{scale_factors[[area_name]]}x {area_full_name[[2]]}"),
          x = placement_params[[area_name]][["x"]] + scale_buffer_horizontal,
          y = placement_params[[area_name]][["y"]] +
            placement_params[[area_name]][["height"]] -
            scale_buffer_vertical,
          hjust = 0,
          vjust = 1,
          fontfamily = viz_config[["scale_font"]],
          color = viz_config[["scale_font_color"]],
          size = viz_config[["scale_font_size"]]
        )
      } else {  
        # Upper left
        draw_label(
          stringr::str_glue("{scale_factors[[area_name]]}x {area_full_name}"),
          x = placement_params[[area_name]][["x"]] + scale_buffer_horizontal,
          y = placement_params[[area_name]][["y"]] +
            placement_params[[area_name]][["height"]] -
            scale_buffer_vertical,
          hjust = 0,
          vjust = 1,
          fontfamily = viz_config[["scale_font"]],
          color = viz_config[["scale_font_color"]],
          size = viz_config[["scale_font_size"]]
        )
      }
  })
  # place extra labels
  drawn_extra_labels <- purrr::map2(
    area_info_df[["name"]], area_info_df[["full_name"]], 
    function(area_name, area_full_name) {
      if (area_name == "GU_MP") {
        draw_label(
          stringr::str_glue("{area_full_name[[1]]}"),
          x = placement_params[[area_name]][["x"]] + 
            placement_params[[area_name]][["width"]]/2,
          y = placement_params[[area_name]][["y"]] +
            placement_params[[area_name]][["height"]]*0.15,
          hjust = 0,
          vjust = 1,
          fontfamily = viz_config[["scale_font"]],
          color = viz_config[["scale_font_color"]],
          size = viz_config[["scale_font_size"]]
        )
      }
    })
  
  # add plots, scale markers, and labels to figure
  plot <- plot + drawn_plots
  
  if (draw_scale_markers) {
    plot <- plot + drawn_scale_markers
  }
  
  if (draw_labels) {
    plot <- plot + drawn_labels + drawn_extra_labels
  }
  
  # add locator map
  if (!is.null(locator_map_png)) {
    locator_img <- magick::image_read(locator_map_png)
    
    locator_map_x <- 0.02
    locator_map_y <- locator_map_x / plot_width_cowplot_scalar
    locator_map_width <- 0.12
    locator_map_height <- locator_map_width / plot_width_cowplot_scalar
    
    plot <- plot +
      draw_image(
        locator_img,
        x = placement_params[["CONUS"]][["x"]] + locator_map_x,
        y = locator_map_y,
        width = locator_map_width,
        height = locator_map_height,
        hjust = 0,
        vjust = 0
      )
  }
  
  return(plot)
  
}
