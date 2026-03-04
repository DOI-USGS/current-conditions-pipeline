FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Minimal system deps that conda/pixi can't provide
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install pixi
RUN curl -fsSL https://pixi.sh/install.sh | bash
ENV PATH="/root/.pixi/bin:$PATH"

# Copy pixi environment files
COPY pixi.toml pixi.lock ./

# Avoiding "Skipped running the post-link scripts"
RUN pixi config set --local run-post-link-scripts insecure

# Install all Python + R deps from lock file
RUN pixi install

# Install CRAN-only packages (not available on conda-forge)
RUN pixi run Rscript -e ".libPaths()"
RUN pixi run Rscript -e "install.packages(c('sfarrow', 'retry'), repos = 'http://cran.us.r-project.org')"

# Install GitHub-only R package (not available on conda-forge)
RUN mkdir /usr/local/lib/R/site-library
RUN chmod -R 777 /usr/local/lib/R/site-library
RUN pixi run Rscript -e "remotes::install_github('DOI-USGS/dataRetrieval', ref='df7edad434e3c804ca30354132e5b4dae6c8f435', upgrade='never', lib='/usr/local/lib/R/site-library')"

# Sanity checks
RUN pixi run R -e "library(dataRetrieval); packageVersion('dataRetrieval')"
RUN pixi run python - << 'EOF'
import dataretrieval
import dataretrieval.waterdata
import pandas
import pyarrow
EOF
