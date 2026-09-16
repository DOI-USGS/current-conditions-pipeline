FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Minimal system deps that conda/pixi can't provide
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    libgl1 \
    libglib2.0-0 \
    cmake \
    libmbedtls-dev \
    fontconfig unzip grep sed \
    && rm -rf /var/lib/apt/lists/*

# Install Source Sans Pro (TTF) from GitHub
RUN mkdir -p /usr/share/fonts/truetype/source-sans-pro && \
    for font in \
    SourceSans3-Black.ttf \
    SourceSans3-BlackIt.ttf \
    SourceSans3-Bold.ttf \
    SourceSans3-BoldIt.ttf \
    SourceSans3-ExtraLight.ttf \
    SourceSans3-ExtraLightIt.ttf \
    SourceSans3-It.ttf \
    SourceSans3-Light.ttf \
    SourceSans3-LightIt.ttf \
    SourceSans3-Medium.ttf \
    SourceSans3-MediumIt.ttf \
    SourceSans3-Regular.ttf \
    SourceSans3-Semibold.ttf \
    SourceSans3-SemiboldIt.ttf; do \
    curl -fsSL "https://raw.githubusercontent.com/adobe-fonts/source-sans/ed1808970eb3c7301c9a523bee26473ba0bb62fa/TTF/${font}" \
    -o "/usr/share/fonts/truetype/source-sans-pro/${font}"; \
    done && \
    fc-cache -fv

# Install pixi
RUN curl -fsSL https://pixi.sh/install.sh | bash
ENV PATH="/root/.pixi/bin:$PATH"

# Copy pixi environment files
COPY pixi.toml pixi.lock ./

# Avoiding "Skipped running the post-link scripts"
RUN pixi config set --local run-post-link-scripts insecure

# Install all Python + R deps from lock file
RUN pixi install

# Install software for simplifying geometries, mapshaper
RUN pixi run install-mapshaper

# Install software for compressing images, pngquant
RUN pixi run install-pngquant

# Check R libPaths location
RUN pixi run Rscript -e ".libPaths()"

# Need to use custom R user directory for packages installed outside pixi.toml
RUN mkdir -p /root/R/library
ENV R_LIBS_USER=/root/R/library

# Install CRAN-only packages (not available on conda-forge)

# Note that rmapshaper is technically available on conda-forge at time of writing,
# but it can't resolve with R 4.X.X because rgeojson, one of its 
# dependencies, is compiled with an old version of R. This is a workaround.

# av is also available on conda-forge, but not available for Windows for some reason.
# It's possible to specify only MacOS/Linux, but I figured this would be easiest to ensure
# consistency across platforms
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
# dataRetrieval v2.7.25 — first release containing DOI-USGS/dataRetrieval PR #896
RUN pixi run Rscript -e "remotes::install_github('DOI-USGS/dataRetrieval', ref='52292cd3781fdd3a3d78e85b3eea329052ba8b1c', upgrade='never', lib='/root/R/library')"

# Sanity checks
RUN pixi run R -e "library(dataRetrieval); packageVersion('dataRetrieval')"
RUN pixi run python -c "import dataretrieval; print(dataretrieval.__version__); print(dataretrieval.__file__)"
RUN pixi run python -c "import dataretrieval.waterdata; print(dir(dataretrieval.waterdata))"
RUN pixi run python - << 'EOF'
import dataretrieval
import dataretrieval.waterdata
import pyarrow
EOF

# Clear any stale matplotlib font cache
RUN find /root -name "fontList*.json" -delete 2>/dev/null || true

# Set Source Sans 3 as default matplotlib font
RUN mkdir -p /root/.config/matplotlib && \
    echo "font.family: sans-serif" >> /root/.config/matplotlib/matplotlibrc && \
    echo "font.sans-serif: Source Sans 3, DejaVu Sans" >> /root/.config/matplotlib/matplotlibrc

# Confirm matplotlib can find Source Sans 3
RUN pixi run python -c "import matplotlib.font_manager as fm; fm._load_fontmanager(try_read_cache=False); fonts = sorted(set([f.name for f in fm.fontManager.ttflist])); print('Found fonts:', [f for f in fonts if 'Source' in f]); print('All sans-serif sample:', fonts[:30])"