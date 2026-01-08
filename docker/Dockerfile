FROM rocker/r-ver:4.3.2

# System deps
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    ca-certificates \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# R packages
RUN R -e "install.packages(c( \
    'dataRetrieval', \
    'ggplot2', \
    'dplyr', \
    'tidyr', \
    'lubridate', \
    'arrow', \
    'purrr', \
    'tidytable', \
  ), repos='https://cloud.r-project.org')"

# Python packages
RUN pip3 install --no-cache-dir \
    dataretrieval \
    pandas \
    numpy \
    matplotlib \
    pyarrow \
    boto3 \
    s3fs

WORKDIR /work
