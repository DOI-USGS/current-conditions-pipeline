# Current Conditions Pipeline

## Introduction

This repository processes and visualizes real-time groundwater and streamflow data from USGS sources.

## Running the pipeline

For **streamflow**, the list of active sites is re-created once a week (Sundays at 4 am ET).
For **groundwater**, the list of active sites is re-created every day based on the criteria explained above.
This is because it's relatively quick to pull groundwater data (there's less of it than streamflow)

## Workflow details

Below is the generic workflow implemented in this repository:

1. Generate a list of "active" sites.
2. For each active site,
   2.1 fetch the most recent conditions.
   2.2 fetch historical percentiles related to those conditions.
   2.3 categorize the recent conditions relative to the historical percentile (e.g., between the minimum and 5th percentile, 5th and 10th, etc.)
3. Visualize the percentile categorizations on a map
4. Save the map visual in a variety of formats to an AWS S3 bucket

### 1. Active site list

We categorize sites as "groundwater" or "streamflow" based on whether they report specific parameter codes.
We determine whether a site is "active" if it has percentiles retrievable through the [/statistics](https://api.waterdata.usgs.gov/statistics/v0/docs) API, which only provides percentiles for sites that meet minimum data availability criteria.

1. Has a daily mean timeseries for one of a list of parameter codes (see GW_PCODES and SW_PCODES in `.gitlab-ci'yml` file)
   - **Groundwater** parameter codes are 72019, 62611, 62610, 72150, 72229, 62600, 30210, 62613, 62612, 72231, 72232, 72230, 72227, 72228, 72226, 61055, 62601
   - **Streamflow** parameter codes are 00060 and 00065.
2. Has a full set of percentiles available through the [/statistics](https://api.waterdata.usgs.gov/statistics/v0/docs) API.
   - **Groundwater** month-of-year percentiles
   - **Streamflow** day-of-year percentiles
   - A "full" percentile set is: minimum, 5th, 10th, 25th, 50th (median), 75th, 90th, 95th, and maximum

Some sites report multiple parameter codes or summaries.
In this case the site would have multiple associated timeseries IDs, one for each combination of parameter code, statistic, and any other qualifiers that uniquely distinguish one measurement from another.
For each site, we identify a single timeseries ID as the "preferred" ID based on some opinionated ranking (e.g., which has the most recent observation, the longest POR, etc).

### 2. Fetching recent conditions

### 3. Visualize

### 4. Save
