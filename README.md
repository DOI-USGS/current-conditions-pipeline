# Current Conditions Pipeline

Software that processes and visualizes near–real-time groundwater and streamflow data from U.S. Geological Survey (USGS) sources

Authors: Jeffrey Kwang, Hayley Corson-Dosch, Elmera Azadpour, Cee Nell, and Joe Zemmels

Point of contact: Jeffrey Kwang (jkwang@usgs.gov)

Repository Type: GitLab CI, Python, and R scripts

Year of Origin: 2026 (original publication)

Year of Version: 2026

Digital Object Identifier (DOI): https://doi.org/10.5066/P15S8PGB

USGS Information Product Data System (IPDS) no.: IP-193154 (internal agency tracking)

A newer version of the software may be available. See https://code.usgs.gov/water/computational-tools/current-conditions-pipeline/-/releases to view all releases.

Citation
Kwang, J.K., Corson-Dosch, H.R., Azadpour E., Nell, C., and Zemmels, J.R. 2025. Current Conditions Pipeline. U.S. Geological Survey software release. Reston, VA. https://doi.org/10.5066/P15S8PGB

## Introduction

This repository processes and visualizes near–real-time groundwater and streamflow data from U.S. Geological Survey (USGS) sources.
It uses a combination of R, Python, and GitLab CI to generate regularly updated map-based visualizations and publish them to AWS S3.

The pipeline is designed to balance data completeness, update frequency, and API constraints while maximizing the number of sites included in each visualization.

## Pipeline cadence

The pipeline runs on different schedules depending on data type:

- Streamflow
  - The list of active sites is rebuilt weekly (Sundays at 4:00 AM ET).
  - Visuals are updated multiple times per day.
- Groundwater
  - The list of active sites is rebuilt daily.
  - Visuals are updated daily.

This difference reflects the relative size and availability of groundwater vs. streamflow datasets.

## High-level workflow

The generic workflow implemented in this repository is:

1. Generate a list of active sites.
2. For each active site:
   - Fetch the most recent conditions.
   - Fetch historical percentiles associated with those conditions.
   - Categorize recent conditions relative to historical percentiles (e.g., minimum–5th, 5th–10th, 10th–25th, etc.).
3. Visualize percentile categories on a map.
4. Save visual outputs in multiple formats to an AWS S3 bucket.

### 1. Active site definition

Sites are categorized as groundwater or streamflow based on reported parameter codes.

A site is considered active if it satisfies both of the following conditions.

#### 1.1 Parameter code eligibility

The site must report a daily mean timeseries for at least one eligible parameter code (defined as GW_PCODES and SW_PCODES in the .gitlab-ci.yml file).
These codes were selected in consultation with subject-matter experts.

**Groundwater parameter codes**: 72019, 62611, 62610, 72150, 72229, 62600, 30210, 62613, 62612, 72231, 72232, 72230, 72227, 72228, 72226, 61055, 62601

**Streamflow parameter codes**: 00060 (discharge), 00065 (gage height)

All groundwater parameters are monotonic transformations of water level, meaning their order statistics are comparable.
For streamflow, gage height and discharge are assumed to be monotonic.

#### 1.2 Percentile availability

The site must have a "complete" percentile set available through the /statistics API.

**Groundwater**: month-of-year percentiles

**Streamflow**: day-of-year percentiles

A full percentile set consists of:

- minimum
- 5th, 10th, 25th
- 50th (median)
- 75th, 90th, 95th
- maximum

### 2. Fetching recent conditions

Recent observations are retrieved using Water Data API endpoints appropriate to the data type:

- Streamflow: /continuous data

- Groundwater: /daily summaries

Additional logic is applied (described below) to ensure the fetched data are both recent and comparable to historical percentiles.

### 3. Visualization

Categorized percentile values are rendered as map-based visualizations.
Each site is symbolized according to where its recent condition falls relative to its historical distribution.

### 4. Output and storage

Final map products are exported in multiple formats and written to an AWS S3 bucket for downstream use.

## Workflow constraints and design trade-offs

Many pipeline design decisions reflect trade-offs between competing constraints.
These compromises are not necessarily optimal for every use case, but represent a good-faith balance given current data availability and API limitations.

### API and data constraints

- **Request limits**: Water Data API endpoints (e.g., /daily, /continuous, /time-series-metadata) are limited to 1000 requests per hour when using an API token.
- **Request size limits**: Requests are constrained by maximum request size (effectively a character limit), requiring long lists of timeseries IDs to be broken into chunks.
- **Pagination limits**: Responses are paginated at 50,000 rows per page, with each page counting against the hourly request quota.
- **Data availability and gaps**: Percentile computation requires sufficient historical coverage for every day- or month-of-year. This excludes many recently commissioned sites and sites for which data are collected infrequently.

### Project constraints

- **Update frequency**: Visuals must update at least daily (groundwater) and multiple times per day (streamflow).
- **Maximizing site coverage**: The goal is to visualize as many sites as possible within the above constraints.
- **Current conditions**: Approval and aggregation delays between /continuous and /daily data affect how “current” data can be.

### Methodological constraints

- **Avoid wasteful requests**: Sites unlikely to meet visualization criteria are filtered early to minimize unnecessary API usage.

## Key compromises and implementation strategies

- **Active site pre-filtering**
  Rather than querying all historical and inactive sites, the pipeline pre-filters to sites with long periods of record (20 years for streamflow, 10 years for groundwater) for specific parameter codes (listed above). This reduces the candidate pool to a few thousand sites.
- **Using `/statistics` as a coverage proxy**
  Instead of manually computing percentiles and assessing coverage, which would be time- and resource-intensive, a site is included if and only if the required percentiles are available via `/statistics`. This simplifies logic and avoids large volumes of discarded data, at the cost of trusting the `/statistics` service to remain stable and consistent.
- **Preferred timeseries IDs**
  Sites often report multiple timeseries (e.g., discharge vs. gage height, daily mean vs. daily max). A single preferred timeseries ID is selected per site using heuristics (longest period of record, most recent observation). Fallback IDs are queried only if the preferred ID lacks data, reducing request volume.
- **Streamflow 24-hour sliding window**
  Rather than comparing a single continuous observation to day-of-year percentiles, the pipeline computes the mean of the last 24 hours of continuous observations. This smooths volatility and aligns better with multiple daily updates. This approach differs from the National Water Dashboard but was judged more informative for this use case.
- **Groundwater statistics and percentile alignment**
  Both daily mean and daily maximum groundwater summaries are included to avoid regional data gaps. Daily groundwater values are compared to month-of-year percentiles, consistent with existing USGS statistical graphs.

## Performance optimizations

- **CI parallelization**
  The active site list requires hundreds of /statistics requests. Timeseries IDs are split into shards and processed in parallel GitLab CI jobs, substantially reducing runtime.
- **Timeseries ID chunking**
  To balance request size limits and pagination: Requests are packed to approach (but not exceed) the 50,000-row page limit. For example, if requesting a year of `/daily` data, package `floor(50000 / 365) = 136` timeseries IDs per request.
- **Scheduled pipeline execution**
  Because the `/statistics` database updates weekly, percentile coverage checks are run weekly. This avoids unnecessary percentile queries while keeping visuals current. The visualization CI jobs are run on a more frequent schedule.
