#' Build bounding box of input sf, with interpolated vertices and options to
#'  extend and shift longitude
#'
#' @param sf an sf object
#' @param ortho_proj_string chr; crs string of the orthographic projection
#'   generated for the output
#' @param shift_longitude lgl, should longitudes < 0 be added to 360? This
#'   is useful when plotting through the date line.
#' @param buffer_m num; meters that `sf` should be buffered by to extend the
#' bounding box
#'
#' @return sf object
#' 
build_bbox <- function(sf, ortho_proj_string, shift_longitude, buffer_m) {
  # Transform input to lat/long
  sf <- st_transform(sf, crs = "EPSG:4326")
  
  # Shift longitude to handle the date line
  if(shift_longitude) {
    sf <- st_shift_longitude(sf)
  }
  
  # Buffer shape to extend bounding boxes
  sf_ext <- st_buffer(sf, dist = units::as_units(buffer_m, "meters"))
  
  # Shift longitude to handle the date line
  if(shift_longitude) {
    sf_ext <- st_shift_longitude(sf_ext)
  }
  
  # Get bounding box
  sf_ext <- st_bbox(sf_ext)
  
  # Interpolate vertices for box to properly display curvature of earth
  sf_ext_df <- data.frame(
    longitude = c(sf_ext$xmax, sf_ext$xmin, sf_ext$xmin, sf_ext$xmax),
    latitude = c(sf_ext$ymax, sf_ext$ymax, sf_ext$ymin, sf_ext$ymin)
  ) |> 
    slice(c(1:n(), 1)) |> 
    interp_rows(group = NULL, n = 49) |> 
    filter(!if_all(everything(), is.na)) |> 
    head(-1)
  
  # Convert to an sf object via an s2
  sf_ext_poly <- s2_make_polygon(
    longitude = sf_ext_df$longitude,
    latitude = sf_ext_df$latitude
  ) |> 
    as_s2_geography(oriented = FALSE) |>
    st_as_sfc() |>
    st_transform(ortho_proj_string) |> 
    st_as_sf()
  
  return(sf_ext_poly)
  
}

#' Interpolate between rows (within groups)
#'
#' @param in_df data frame
#' @param group unquoted column name to group by; if `NULL` (default),
#'   interpolate between all rows
#' @param n integer; number of rows to add within each group
#'
#' @return
#' 
interp_rows <- function(in_df, group = NULL, n) {
  
  # Add grouping column
  if(is.null(substitute(group))) {
    df_grouped <- mutate(in_df, n = row_number()) |>
      group_by(n)
  } else {
    df_grouped <- group_by(in_df, {{group}})
  }
  
  out <- df_grouped |> 
    # Within group, add rows filled with NA
    group_modify(
      ~ add_row(.x, "{colnames(.x)[1]}" := rep(NA, n),  .after = 1)
    ) |>
    # Interpolate NA values based on nearest non-NA row before and after
    zoo::na.approx() |>
    as_tibble() |> 
    # Remove grouping column if added by this function
    dplyr::select(all_of(colnames(in_df)))
  
  return(out)
}

#' Call fxn to generate orthographic map view of bounding box
#' 
#' Calls `extent_locator_map()` to make a locator map for an area or areas
#' 
#' @param area_name Name of area for which to generate locator map.
#' @param in_map ggplot (of sf objects) or object is of class sf, sfc, Spatial
#'   or Raster. Object which extent can be determined.
#' @param add_sf sf object, additional sf object to plot on map
#' @param shift_longitude logical, should longitudes < 0 be added to 360? This
#'   is useful when plotting through the date line.
#' @param box_color character, color of bounding box
#' @param box_linewidth numeric, linewidth of bounding box
#' @param graticules integer (divisible by 180); graticule degrees; if NULL,
#'   do not plot graticules
#' @param add_sf_ext lgl; add bounding box around `add_sf` elements
#' @param buffer_m_add_sf num; meters that `sf` should be buffered by to extend
#'   the bounding box around add_sf
#' @param viz_cfg Visual config (for dimensions/colors)
#' @param output_template Filename template containing `%s` for `area_name`.
#' 
#' @returns path to saved locator map png
generate_extent_locator_map <- function(area_name, in_map, add_sf, shift_longitude,
                                        graticules, add_sf_ext, buffer_m_add_sf, viz_cfg,
                                        output_template) {
  # Create locator map
  locator_map <- extent_locator_map(
    # Full map scene
    in_map = in_map,
    # Countries of interest to map
    add_sf = add_sf,
    # Fix drawing across the date line
    shift_longitude = shift_longitude,
    # 30 degree graticules
    graticules = graticules,
    add_sf_ext = add_sf_ext,
    buffer_m_add_sf = buffer_m_add_sf,
    # aes for states of interest
    fill = viz_cfg[["locator_map_focal_area_color"]],
    color = viz_cfg[["locator_map_focal_area_color"]],
    linewidth = 0.2
  )
  
  # save locator map
  out_path <- sprintf(output_template, area_name)
  ggsave(out_path, 
         locator_map, 
         width = viz_cfg[["locator_map_width"]], 
         height = viz_cfg[["locator_map_height"]], 
         bg = viz_cfg[["bg_col"]], 
         dpi = viz_cfg[["dpi"]],
         units = viz_cfg[["units"]])
  
  return(out_path)
}

#' Create orthographic map view of bounding box
#' 
#' Creates a ggplot of an orthographic locator map showing the extent of in_map
#'   displayed as a box on the globe. Intended to be used for creating extent
#'   indicator maps.
#'
#' @param in_map ggplot (of sf objects) or object is of class sf, sfc, Spatial
#'   or Raster. Object which extent can be determined.
#' @param add_sf sf object, additional sf object to plot on map
#' @param shift_longitude logical, should longitudes < 0 be added to 360? This
#'   is useful when plotting through the date line.
#' @param box_color character, color of bounding box
#' @param box_linewidth numeric, linewidth of bounding box
#' @param graticules integer (divisible by 180); graticule degrees; if NULL,
#'   do not plot graticules
#' @param add_sf_ext lgl; add bounding box around `add_sf` elements
#' @param buffer_m_add_sf num; meters that `sf` should be buffered by to extend
#'   the bounding box around add_sf
#' @param ... additional arguments passed to geom_sf for `add_sf`, usually used
#'   to set aesthetics, such as `color = "red"`
#'
#' @return a ggplot object
#' 
#' @import ggplot2
#' @import sf
#' @import s2 
#'
#' @examples
#' rnaturalearth::ne_countries(country = "spain", returnclass = "sf") |> 
#'   extent_locator_map()
#' 
extent_locator_map <- function(in_map, buffer_m_in_map = 200000, add_sf = NULL,
                               shift_longitude = FALSE, box_color = NA,
                               box_linewidth = 0.3, graticules = 30,
                               add_sf_ext = TRUE,
                               buffer_m_add_sf = 200000, ...) {
  
  # Get in_map extent
  # Handle errors related to input types
  if(is_ggplot(in_map)){
    
    if(!"CoordSf" %in% class(ggplot_build(in_map)$layout$coord)) {
      
      stop("If in_map is a ggplot, it must be a CoordSf plot")
    }
    
    in_map <- in_map +
      coord_sf(crs = "EPSG:4326")
    
    in_map_ext <- ggplot_build(in_map)$layout$panel_params[[1]][c("x_range", "y_range")] |>
      unlist() |> 
      setNames(c("xmin", "xmax", "ymin", "ymax")) |> 
      st_bbox()
    
  } else if(class(try(st_bbox(in_map), silent = TRUE)) != "try-error") {
    
    # Shifts longitude to plot across the date line
    if(shift_longitude) {
      
      in_map <- st_shift_longitude(in_map)
      
    }
    
    in_map_ext <- st_bbox(in_map)
    
  } else {
    
    stop("in_map must either (1) be a ggplot or (2) be able to be input into sf::st_bbox")
    
  }
  
  # Get input map extent centroid in lat/long
  in_map_centroid <- in_map_ext |>
    st_as_sfc() |>
    st_geometry() |>
    st_centroid() |>
    st_coordinates() |>
    as.data.frame() |>
    round(3) 
  
  # Get point buffer as s2 geography
  in_map_buffer <- in_map_centroid |>
    paste(collapse = " ") |>
    sprintf("POINT (%s)", ... = _) |> 
    as_s2_geography()
  
  # Define orthographic map projection
  ortho_proj_string <- sprintf(
    "+proj=ortho +lat_0=%s +lon_0=%s",
    in_map_centroid$Y,
    in_map_centroid$X
  )
  message(ortho_proj_string)
  # Get world map
  world_s2_geog <- s2_data_countries() |>
    as_s2_geography()
  
  # Define buffer so only visible half of globe shows ()
  center_buffer <- s2_buffer_cells(in_map_buffer, 9800000)
  
  # Generate world map as s2 in orthographic projection
  map_ortho <- s2_intersection(center_buffer, world_s2_geog) |>
    st_as_sfc() |>
    st_transform(ortho_proj_string)
  
  # Generate circle that represents visible half of globe
  map_buffer <- center_buffer |>
    st_as_sfc() |>
    st_transform(ortho_proj_string)
  
  # Define coordinates for bounding box polygon
  # If not interpolated like this, line does not show curvature of earth
  in_map_box <- build_bbox(
    sf = in_map,
    ortho_proj_string = ortho_proj_string,
    shift_longitude = shift_longitude,
    buffer_m = buffer_m_in_map
  )
  
  # Prep add_sf
  if(!is.null(add_sf)) {
    
    if("list" %in% class(add_sf)) {
      add_sf_ext_box <- map(
        add_sf,
        ~build_bbox(
          sf = .x,
          ortho_proj_string = ortho_proj_string,
          shift_longitude = shift_longitude,
          buffer_m = buffer_m_add_sf
        )
      ) |> 
        dplyr::bind_rows()
      
      add_sf <- dplyr::bind_rows(add_sf)
      
    } else {
      
      add_sf_ext_box <- build_bbox(
        sf = add_sf,
        ortho_proj_string = ortho_proj_string,
        shift_longitude = shift_longitude,
        buffer_m = buffer_m_add_sf
      )
      
    }
    
    add_sf_prepped <-  st_transform(add_sf, ortho_proj_string)
    
  }
  
  # Make graticules
  if(!is.null(graticules)) {
    
    # Define coordinates for graticules
    # If not interpolated like this, lines do not show curvature of earth
    grat_df <- rbind(
      # Latitude graticules
      data.frame(
        longitude = rep(c(-180, 180), times = (180 / graticules + 1)),
        latitude = rep(seq(-90, 90, by = graticules), each = 2),
        feature_id = rep(1: (180 / graticules + 1), each = 2)
      ) |> 
        interp_rows(group = feature_id, n = 50),
      
      # Longitude graticules
      data.frame(
        longitude = rep(seq(-180, 180, by = graticules), each = 2),
        latitude = rep(c(-90, 90), times = (360 / graticules + 1)),
        feature_id = rep(1: (360 / graticules + 1), each = 2)
      ) |> 
        interp_rows(group = feature_id, n = 198)
    )
    
    # Generate graticule lines
    grat_lines <- s2_make_line(
      longitude = grat_df$longitude,
      latitude = grat_df$latitude,
      feature_id = grat_df$feature_id
    ) |>
      as_s2_geography(oriented = FALSE) |>
      s2_intersection(x = _, y = center_buffer) |>
      st_as_sfc()|>
      st_transform(ortho_proj_string)
    
  }
  
  # Make plot
  out_plot <- ggplot() +
    # Add globe
    geom_sf(data = map_buffer, fill = "#FAFAFA", color = NA) +
    # Add land
    geom_sf(data = map_ortho, fill = "#B3B3B3", color = "#E5E5E5", linewidth = 0.15) +
    # Add bounding box
    geom_sf(data = in_map_box, color = box_color, fill = NA, linewidth = box_linewidth) +
    # Add outline around globe
    geom_sf(data = map_buffer, fill = NA, color = "#7F7F7F", linewidth = 0.2) +
    scale_x_continuous(expand = c(0.01, 0.01)) +
    scale_y_continuous(expand = c(0.01, 0.01)) +
    theme_void()
  
  if(!is.null(graticules)) {
    out_plot <- out_plot +
      # Add graticules
      geom_sf(data = grat_lines, color = "#A6A6A6", linewidth = 0.1)
  }
  
  if(!is.null(add_sf)) {
    
    out_plot <- out_plot +
      # Add add_sf
      geom_sf(data = add_sf_prepped, ...)
  }
  
  if(!is.null(add_sf) & add_sf_ext) {
    
    out_plot <-  out_plot +
      # Add add_sf bounding boxes
      geom_sf(data = add_sf_ext_box, fill = NA, color = "black", linewidth = 0.2)
    
  }
  
  return(out_plot)
}