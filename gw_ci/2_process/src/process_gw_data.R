#' Process groundwater conditions for a single date
#'
#' Compute derived fields used for binned peak visualizations.
#'
#' @param gw_conditions Daily groundwater condition data.
#' @param scales Visualization scale parameters.
#'
#' @return An sf object with derived plotting variables.
process_gw_join <- function(gw_conditions, scales) {
  sf_df <- gw_conditions |>
    mutate(
      per_bin = case_when(
        category == "<5"  ~ "Extremely below",
        category == "5-10" ~ "Much below",
        category == "10-25" ~ "Below normal",
        category == "25-75" ~ "Normal",
        category == "75-90" ~ "Above normal",
        category == "90-95" ~ "Much above",
        category == ">95" ~ "Extremely above",
        TRUE ~ NA_character_
      ),
      direction = case_when(
        category %in% c("25-75", "75-90", "90-95", ">95") ~ 1,
        category %in% c("<5", "5-10", "10-25") ~ -1,
        TRUE ~ NA_real_
      ),
      plotting_order = case_when(
        category %in% c("25-75") ~ 1,
        category %in% c("10-25", "75-90") ~ 2,
        category %in% c("5-10", "90-95") ~ 3,
        category %in% c("<5", ">95") ~ 4,
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
      y_end = y + y_dif,
      # Per site scaling multiplier for peaks based on order
      halo_factor = case_when(
        plotting_order == 2 ~ scales$min_factor,
        plotting_order == 3 ~ scales$mid_factor,
        plotting_order == 4 ~ 1,
        TRUE ~ NA_real_
      )
    ) |>
    arrange(plotting_order)
  
}
