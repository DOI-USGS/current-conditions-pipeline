library(dplyr)
library(httr2)
library(readr)
library(purrr)
library(tibble)

begin_date <- as.Date("2025-01-01")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  end_date <- as.Date(args[[1]])
} else {
  end_date <- Sys.Date() - 1
}

stopifnot(begin_date <= end_date)

dates <- seq.Date(begin_date, end_date, by = "day")

url_begin <- "https://dfi09q69oy2jm.cloudfront.net/visualizations/"
gw_path <- "current_conditions/groundwater/"

base_request <- httr2::request(url_begin) |>
  httr2::req_url_path_append(gw_path) |>
  httr2::req_method("HEAD") |>
  httr2::req_error(is_error = function(x) FALSE)

expected_parquet <- c("parquet_file" = "gw_categorizations")

expected_webp_images <-
  c(
    "mobile_CONUS_image_file" = "gw-mobile-CONUS",
    "mobile_AK_image_file" = "gw-mobile-AK",
    "mobile_HI_image_file" = "gw-mobile-HI",
    "mobile_PR_VI_image_file" = "gw-mobile-PR_VI",
    "mobile_GU_MP_image_file" = "gw-mobile-GU_MP",
    "mobile_AS_image_file" = "gw-mobile-AS",
    "desktop_CONUS_OCONUS_image_file" = "gw-desktop-CONUS_OCONUS"
  )

expected_png_images <-
  c(
    "desktop_static_CONUS_OCONUS_image_file" = "gw-static-desktop-CONUS_OCONUS"
  )

date_files <-
  purrr::map_dfr(dates, function(date) {
    print(date)
    expected_content <-
      c(
        paste0("stage/", expected_parquet, "_", date, ".parquet"),
        paste0("images/", expected_webp_images, "-", date, ".webp"),
        paste0("images/", expected_png_images, "-", date, ".png")
      )

    purrr::map2_dfc(
      expected_content,
      names(c(expected_parquet, expected_webp_images, expected_png_images)),
      function(file_path, col_name) {
        response <- base_request |>
          httr2::req_url_path_append(file_path) |>
          httr2::req_perform()

        # the httr2 request will return a 403 eror if the file doesn't exist.
        if (httr2::resp_is_error(response)) {
          return(tibble::tibble_row(!!col_name := NA_character_))
        } else {
          return(tibble::tibble_row(!!col_name := paste0(gw_path, file_path)))
        }
      }
    ) |>
      dplyr::mutate(date = date, .before = 1)
  })

expected_videos <- c(
  "desktop_static_CONUS_OCONUS_mp4_last_month" = "videos/gw-movie-desktop-CONUS_OCONUS-last-month.mp4",
  "desktop_static_CONUS_OCONUS_mp4_last_3_months" = "videos/gw-movie-desktop-CONUS_OCONUS-last-3-months.mp4",
  "desktop_static_CONUS_OCONUS_mp4_last_6_months" = "videos/gw-movie-desktop-CONUS_OCONUS-last-6-months.mp4",
  "desktop_static_CONUS_OCONUS_mp4_last_year" = "videos/gw-movie-desktop-CONUS_OCONUS-last-year.mp4"
)

# Note: this just checks whether the files exist, not when the files were last updated. The video files aren't
# distinguished by date other than their "last modified" status. This is a basic "are they still there?" check,
# not "were they updated to show the most recent data?"
video_files <-
  purrr::map2_dfc(
    expected_videos,
    names(expected_videos),
    function(file_path, col_name) {
      response <- base_request |>
        httr2::req_url_path_append(file_path) |>
        httr2::req_perform()

      if (httr2::resp_is_error(response)) {
        return(tibble::tibble_row(!!col_name := NA_character_))
      } else {
        return(tibble::tibble_row(!!col_name := paste0(gw_path, file_path)))
      }
    }
  ) |>
  dplyr::mutate(date = max(dates), .before = 1)

metadata <-
  date_files |>
  dplyr::left_join(video_files, by = "date")

readr::write_csv(metadata, file = "gw_ci/4_update/out/gw_file_metadata.csv")
