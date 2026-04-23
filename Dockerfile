FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Minimal system deps that conda/pixi can't provide
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    libgl1 \
    libglib2.0-0 \
    fontconfig unzip grep sed \
    && rm -rf /var/lib/apt/lists/*

# Install Source Sans Pro directly from GitHub
RUN mkdir -p /usr/share/fonts/truetype/source-sans-pro && \
    curl -fsSL "https://github.com/adobe-fonts/source-sans/releases/download/3.052R/OTF-source-sans-3.052R.zip" -o /tmp/SourceSansPro.zip && \
    unzip /tmp/SourceSansPro.zip -d /tmp/source-sans && \
    cp /tmp/source-sans/OTF/*.otf /usr/share/fonts/truetype/source-sans-pro/ && \
    rm -rf /tmp/SourceSansPro.zip /tmp/source-sans && \
    fc-cache -fv

# Clear any stale matplotlib font cache
RUN find /root -name "fontList*.json" -delete 2>/dev/null || true

# Set Source Sans Pro as default matplotlib font
RUN mkdir -p /root/.config/matplotlib && \
    echo "font.family: sans-serif" >> /root/.config/matplotlib/matplotlibrc && \
    echo "font.sans-serif: Source Sans Pro, DejaVu Sans" >> /root/.config/matplotlib/matplotlibrc

# Install pixi
RUN curl -fsSL https://pixi.sh/install.sh | bash
ENV PATH="/root/.pixi/bin:$PATH"

# Copy pixi environment files
COPY pixi.toml pixi.lock ./

# Avoiding "Skipped running the post-link scripts"
RUN pixi config set --local run-post-link-scripts insecure

# Install all Python + R deps from lock file
RUN pixi install
RUN pixi run install-mapshaper

# Check R libPaths location
RUN pixi run Rscript -e ".libPaths()"

# Need to use custom R user directory for packages installed outside pixi.toml
RUN mkdir -p /root/R/library
ENV R_LIBS_USER=/root/R/library

# Install CRAN-only packages (not available on conda-forge)
RUN pixi run Rscript - << "EOF"
remotes::install_version('sfarrow', version = '0.4.1', lib='/root/R/library', repos='https://cran.rstudio.com/')
remotes::install_version('retry', version = '0.1.1', lib='/root/R/library', repos='https://cran.rstudio.com/')
remotes::install_version('av', version = '0.9.6', lib='/root/R/library', repos='https://cran.rstudio.com/')
remotes::install_version('rmapshaper', version = '0.6.0', lib='/root/R/library', repos='https://cran.rstudio.com/')
remotes::install_version('targets', version = '1.12.0', lib='/root/R/library', repos='https://cran.rstudio.com/')
remotes::install_version('tarchetypes', version = '0.14.0', lib='/root/R/library', repos='https://cran.rstudio.com/')
remotes::install_version('USAboundaries', version = '0.5.1', lib='/root/R/library', repos='https://cran.rstudio.com/')
EOF

# Install GitHub-only R package (not available on conda-forge)
RUN pixi run Rscript -e "remotes::install_github('DOI-USGS/dataRetrieval', ref='df7edad434e3c804ca30354132e5b4dae6c8f435', upgrade='never', lib='/root/R/library')"

# Sanity checks
RUN pixi run R -e "library(dataRetrieval); packageVersion('dataRetrieval')"
RUN pixi run python -c "import dataretrieval; print(dataretrieval.__version__); print(dataretrieval.__file__)"
RUN pixi run python -c "import dataretrieval.waterdata; print(dir(dataretrieval.waterdata))"
RUN pixi run python - << 'EOF'
import dataretrieval
import dataretrieval.waterdata
import pandas
import pyarrow
EOF

# Confirm matplotlib can find Source Sans Pro
RUN pixi run python -c "import matplotlib.font_manager as fm; fm._load_fontmanager(try_read_cache=False); fonts = [f.name for f in fm.fontManager.ttflist]; assert 'Source Sans Pro' in fonts, 'Font not found! Available: ' + str(sorted(set(fonts))[:20]); print('Source Sans Pro found OK')"