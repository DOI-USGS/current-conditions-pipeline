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
    r-cran-stringr \
    r-cran-sf \
    r-cran-retry \
    \
    && rm -rf /var/lib/apt/lists/*

# Add symlink so "python" calls work
RUN ln -s /usr/bin/python3 /usr/bin/python

RUN python3 -m pip install --upgrade pip setuptools wheel

# Python packages
RUN pip3 install --no-cache-dir \
    # dataretrieval \
    # Install drpy from Elise's dev fork (for now)
    pandas \
    pyarrow \
    fastparquet \
    numpy \
    matplotlib \
    pyarrow \
    awscli \
    boto3 \
    s3fs \
    -e git+https://github.com/ehinman/dataretrieval-python.git@98e3e867ccdb96056287ef155e17ffb4eb7b12e5#egg=dataretrieval

# Sanity checks
RUN R -e "library(dataRetrieval); packageVersion('dataRetrieval')"
RUN python3 - << 'EOF'
import dataretrieval
import dataretrieval.waterdata
import pandas
import pyarrow
EOF
