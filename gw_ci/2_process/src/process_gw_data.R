#' Process groundwater conditions for a single date
#'
#' Joins daily groundwater quantile data onto site locations and computes
#' derived fields used for binned peak visualizations.
#'
#' @param date A single date corresponding to one timestep.
#' @param gw_conditions Daily groundwater condition data.
#' @param gw_site_coords An sf object of groundwater site locations.
#' @param scales Visualization scale parameters.
#'
#' @return An sf object with derived plotting variables.
process_gw_for_date <- function(date, gw_conditions,
                                gw_site_coords, scales) {

  # join onto sf
  sf_df <- gw_site_coords |>
    left_join(
      gw_conditions |> filter(Date == date),
      by = "site_no"
    ) |>
    mutate(
      per = daily_quant / 100,
      shifted_per = per - 0.5,
      abs_shifted_per = abs(shifted_per),
      per_bin = case_when(
        per >= 0.95 ~ "Extremely above",
        per >= 0.90 ~ "Much above",
        per >= 0.75 ~ "Above normal",
        per >= 0.25 ~ "Normal",
        per >= 0.10 ~ "Below normal",
        per >= 0.05 ~ "Much below",
        per >= 0.00 ~ "Extremely below",
        TRUE ~ NA_character_
      ),
      direction = if_else(per >= 0.25, 1, -1),
      plotting_order = case_when(
        per >= 0.95 ~ 4,
        per >= 0.90 ~ 3,
        per >= 0.75 ~ 2,
        per >= 0.25 ~ 1,
        per >= 0.10 ~ 2,
        per >= 0.05 ~ 3,
        per >= 0.00 ~ 4,
        TRUE ~ NA_real_
      )
    )
  # Extract coordinates
  coords <- sf::st_coordinates(sf_df)
  # Geometry
  sf_df |>
    mutate(
      x = coords[, 1],
      y = coords[, 2],
      x_dif = case_when(
        plotting_order == 1 ~ scales$normal_width,
        plotting_order == 2 ~ scales$min_vector_width,
        plotting_order == 3 ~ scales$mid_vector_width,
        plotting_order == 4 ~ scales$max_vector_width
      ),
      x_start = x - x_dif / 2,
      x_end   = x + x_dif / 2,
      y_dif = case_when(
        plotting_order == 1 ~ 0,
        plotting_order == 2 ~ scales$min_vector_height * direction,
        plotting_order == 3 ~ scales$mid_vector_height * direction,
        plotting_order == 4 ~ scales$max_vector_height * direction
      ),
      y_end = y + y_dif
    ) |>
    arrange(plotting_order)
}
