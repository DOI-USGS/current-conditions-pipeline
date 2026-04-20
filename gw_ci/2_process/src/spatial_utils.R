#' Subset, project, simplify, and get extent of geometries for given area
#'
#' @param states_sf census data geometry for U.S. states and territories
#' @param area_name name of area for which to subset geometries
#' @param area_state_list list of states within `area`
#' @param area_proj proj to use for `area`
#' @param simplification_keep proportion of points to retain (0 - 1)
#'
#' @return sf object subset to `area`, with columns representing spatial extent
munge_area_polys <- function(states_sf, area_name, area_state_list, area_proj, 
                             simplification_keep) {
  
  state_subset <- states_sf |> 
    dplyr::filter(STUSPS %in% unlist(area_state_list)) |> 
    sf::st_transform(area_proj) |> 
    rmapshaper::ms_simplify(simplification_keep)
  
  if (area_name == 'AS') {
    state_subset <- state_subset |> 
      sf::st_cast("POLYGON") |> 
      dplyr::mutate(ID = sprintf("%s_%s", STUSPS, row_number())) |> 
      # filter out outlying ring islands
      # NOTE IDs vary based on level of simplification
      # this works if simplification_keep = 0.1 for AS
      dplyr::filter(ID %in% c('AS_1', 'AS_2', 'AS_3', 'AS_4', 'AS_5'))
  }
  
  bbox <- st_bbox(state_subset)
  state_subset <- state_subset |> 
    dplyr::mutate(
      x_max = unname(bbox$xmax),
      x_min = unname(bbox$xmin),
      x_extent = unname(bbox$xmax - bbox$xmin),
      y_max = unname(bbox$ymax),
      y_min = unname(bbox$ymin),
      y_extent = unname(bbox$ymax - bbox$ymin)
    )
  
  return(state_subset)
}

get_relative_extent_information <- function(area_info_df, area_sf, max_x_extent, 
                                           max_y_extent) {
  tibble(
    state_name = area_info_df[["name"]],
    x_min = unique(area_sf[["x_min"]]),
    x_max = unique(area_sf[["x_max"]]),
    x_extent = unique(area_sf[["x_extent"]]),
    y_min = unique(area_sf[["y_min"]]),
    y_max = unique(area_sf[["y_max"]]),
    y_extent = unique(area_sf[["y_extent"]]),
    rel_width = x_extent/max_x_extent,
    rel_height = y_extent/max_y_extent
  )
}