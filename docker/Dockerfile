FROM rocker/r2u:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# System + R binary deps
RUN apt-get update && apt-get install -y \
    # system utilities
    git \
    curl \
    ca-certificates \
    # awscli \
    libgl1 \
    libglib2.0-0 \
    \
    # python
    python3 \
    python3-pip \
    python3-venv \
    \
    # R system libs
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgit2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    \
    # R packages via r2u
    r-cran-dataretrieval \
    r-cran-dplyr \
    r-cran-tidyr \
    r-cran-lubridate \
    r-cran-purrr \
    r-cran-tidytable \
    r-cran-arrow \
    r-cran-ggplot2 \
    \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/bin/python

# Python packages
RUN pip3 install --no-cache-dir \
    dataretrieval \
    pandas \
    pyarrow \
    fastparquet \
    numpy \
    matplotlib \
    pyarrow \
    awscli \
    boto3 \
    s3fs

# Sanity checks
RUN R -e "library(dataRetrieval); packageVersion('dataRetrieval')"
RUN python3 - << 'EOF'
import dataretrieval
import pandas
import pyarrow
EOF
