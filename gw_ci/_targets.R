library(targets)
library(tarchetypes)

options(tidyverse.quiet = TRUE, timeout = 800)
options(tigris_use_cache = TRUE)
tar_option_set(
  packages = c(
    'tidyverse',
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
    'glue',
    'arrow',
    'sfarrow',
    's2',
    'jsonlite'
  )
)

# Phase target makefiles
source("0_config.R")
source("1_fetch.R")
source("2_process/src/process_gw_data.R")
source("2_process.R")
source("3_visualize.R")
source("3_visualize/src/mapping_utils.R")
source("4_update.R")

# Combined list of target outputs
c(
  p0_targets,
  p1_targets,
  p2_targets,
  p3_targets,
  p4_targets
)
