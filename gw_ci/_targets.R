library(targets)
library(tarchetypes)

options(tidyverse.quiet = TRUE, timeout = 800)
options(tigris_use_cache = TRUE)
tar_option_set(packages = c('tidyverse',
                            'sf',
                            'janitor',
                            'tigris',
                            'sysfonts',
                            'showtext',
                            'cowplot',
                            'rmapshaper',
                            'magick',
                            'ggforce',
                            'ggfx',
                            'av',
                            'glue'
                            ))

# Phase target makefiles
tar_source("0_config.R")
tar_source("1_fetch.R")
tar_source("2_process/src/process_gw_data.R")
tar_source("2_process.R")
tar_source("3_visualize.R")
tar_source("3_visualize.R/src/mapping_utils")


# Combined list of target outputs
c(
  p0_targets,
  p1_targets,
  p2_targets,
  p3_targets
)
