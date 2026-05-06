import re
import pytz
import pandas as pd
from itertools import chain
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta


def blanks_mask(df: pd.DataFrame, cols):
    """
    Returns a boolean DataFrame (same shape as df[cols]) where True means 'blank':
    - NaN/NaT
    - empty or whitespace-only strings
    """
    sub = df[cols].copy()

    # Mark whitespace-only strings as NA, leave other values unchanged
    sub = sub.replace("NA", pd.NA, regex=True)

    # Now NA (including those we just introduced) are blanks
    return sub.isna()


def generate_image_list(
    end_date_str,
    image_prefix,
    video_prefix,
    parquet_prefix,
    layout_params,
    intervals,
    metadata,
):
    """Generates the list of images and parquets to download / generate.

    Parameters
    ----------
    end_date_str: string
        parameters defining the figure style
    image_prefix: string
        folder location and prefix for image files on s3 and local resources
    video_prefix: string
        folder location and prefix for video files on s3 and local resources
    parquet_prefix: string
        folder location and prefix for parquet files on s3 and local resources
    layout_params: dictionary
        parameters defining the layout style
    intervals: list
       list of the intervals need to be generated
    metadata: dataframe
       dataframe that tells use which files exist on s3
 
    Returns
    -------
    Assuming X days of data and Y layouts, we need X * Y images.

    images_to_download: list of strings
        list of images for downloading off of s3, # of images of the X * Y images that exist on s3 already
    images_to_generate: list of strings
        list of images that cannot be downloaded and need to be generated, # of images of the X * Y images that exist on s3 already
    parquets_for_image_generation: list of strings
        list that is the same length as images_to_generate that contains the source data in a parquet file
    layout_for_image_generation: list of strings
        list of the layout code used for the plot, same length as images_to_generate
    video_frame_lists: list of strings
        list of all frames for a particular video
    video_names: list of strings
        list of the video file name
    parquets_to_download_or_generate: list of strings
        list of parquet files needed to download or generate, consist on file names only, the maximum length is the number of parquet files over X days
    parquets_to_download: list of strings
        list of parquet files to download, blanks "" need to be generated, same length as parquets_to_download_or_generate
    date_dict: dictionary
        dictionary holding a list of dates for each interval

    """

    # find largest interval
    max_delta = timedelta(0)
    for interval in intervals:
        # `end_date_str` based on `date` argument to Snakemake
        # Use snakemake --cores all --config date="YYYY-MM-DD"
        end_date = datetime.strptime(end_date_str, "%Y-%m-%d").date()
        start_date = find_start_date(end_date, interval)
        delta = end_date - start_date

        if delta > max_delta:
            max_delta = delta
            max_interval = interval
            full_date_list = []
            current = start_date
            while current <= end_date:
                full_date_list.append(current.strftime("%Y-%m-%d"))
                current += timedelta(days=1)
    
    # metadata cleanup
    # Find ids not in dataframe
    missing_dates = set(full_date_list) - set(metadata["date"])

    # Create new rows for missing dates
    new_rows = pd.DataFrame({"date": list(missing_dates)})

    # Reindex to match df columns (fills others with NA)
    new_rows = new_rows.reindex(columns=metadata.columns)

    # Append
    metadata = pd.concat([metadata, new_rows], ignore_index=True)

    # refresh all image files for the latest date
    metadata.iloc[-1, 1:] = 'NA'

    # determine which parquets need downloading
    # Filter to only the dates you care about
    filtered_metadata = metadata[metadata["date"].isin(full_date_list)]

    # Build the per-row mask: True if the row has at least one blank among the image_file columns
    rows_that_need_image_generation = blanks_mask(
        filtered_metadata,
        [layout["metadata_column"] for layout in layout_params.values()],
    ).any(axis=1)

    # Select the dates for those rows *as a pandas Series*, then convert to a Python list
    dates_that_need_image_generation = filtered_metadata.loc[
        rows_that_need_image_generation, "date"
    ].tolist()

    # Get a list of parquet files that are going to be used to make images
    parquets_to_download_or_generate = [
        parquet_prefix + str(date) + ".parquet"
        for date in dates_that_need_image_generation
    ]
    
    # Get a list of parquet files urls that are going to be downloaded, "NA" means it needs to be generated
    parquets_to_download = [
        (
            metadata.loc[metadata["date"] == d, "parquet_file"].values[0]
            if d in metadata["date"].values
            else "NA"
        )
        for d in dates_that_need_image_generation
    ]

    # Get lists for movie frames
    video_frame_lists = []
    video_names = []
    for layout in layout_params.values():
        if layout["video"] == True:
            for interval in intervals:
                end_date = datetime.strptime(end_date_str, "%Y-%m-%d").date()
                start_date = find_start_date(end_date, interval)
                delta = end_date - start_date

                # Generate list of dates
                date_list = []
                current = start_date
                while current <= end_date:
                    date_list.append(current.strftime("%Y-%m-%d"))
                    current += timedelta(days=1)

                image_list = [
                    image_prefix + layout["prefix"] + str(date) + ".png"
                    for date in date_list
                ]
                video_frame_lists += [image_list]
                video_names += [
                    video_prefix + layout["source_prefix"] + video_label(interval) + ".mp4"
                ]

    # define date dictionary for a json
    date_dict = {}

    # Set timezone to Eastern
    eastern = pytz.timezone('US/Eastern')
    # add latest-update
    date_dict["latest-update"] = datetime.now(eastern).strftime("%B %d, %Y %I:%M %p %Z")

    for interval in intervals:
        for interval in intervals:
            end_date = datetime.strptime(end_date_str, "%Y-%m-%d").date()
            start_date = find_start_date(end_date, interval)
            delta = end_date - start_date

            # Generate list of dates
            date_list = []
            current = start_date
            while current <= end_date:
                date_list.append(current.strftime("%Y-%m-%d"))
                current += timedelta(days=1)

            date_dict[video_label(interval)] = date_list

    # Get a list of images that need to be downloaded
    images_to_download = (
        metadata[[layout["metadata_column"] for layout in layout_params.values()]]
            .replace("NA", pd.NA, regex=True)  # convert "" / "   " → NA
            .stack()
            .dropna()
            .tolist()
        )

    # Get corresponding lists that are the same length as the parquets_for_image_generation list
    images_to_generate = []
    parquets_for_image_generation = []
    layout_for_image_generation = []

    static_images_to_generate = []
    images_for_static_image_generation = []
    layout_for_static_image_generation = []

    for layout in layout_params.keys():
        if layout_params[layout]["static"] == False:
            layout_param = layout_params[layout]
            # Get full list of images needed
            image_list = [
                image_prefix + layout_param["prefix"] + str(date) + ".webp"
                for date in full_date_list
            ]
            # Get corresponding parquet files
            parquet_list = [
                parquet_prefix + str(date) + ".parquet"
                for date in date_list
            ]
            # Get list of images that are on s3
            s3_image_list = [
                (
                    metadata.loc[metadata["date"] == d, layout_param["metadata_column"]].values[0]
                    if d in metadata["date"].values
                    else "NA"
                )
                for d in date_list
            ]
            # list images that aren't on s3
            for j, s3_image in enumerate(s3_image_list):
                if s3_image == "NA":
                    images_to_generate += [image_list[j]]
                    parquets_for_image_generation += [parquet_list[j]]
                    layout_for_image_generation += [layout] 

        elif layout_params[layout]["static"] == True:
            layout_param = layout_params[layout]
            # Get full list of images png images
            static_image_list = [
                image_prefix + layout_param["prefix"] + str(date) + ".png"
                for date in full_date_list
            ]
            # Webp images for making the static png image
            for_static_image_list = [
                image_prefix + layout_param["source_prefix"] + str(date) + ".webp"
                for date in full_date_list
            ]
            # Get list of images that are on s3
            s3_image_list = [
                (
                    metadata.loc[metadata["date"] == d, layout_param["metadata_column"]].values[0]
                    if d in metadata["date"].values
                    else "NA"
                )
                for d in date_list
            ]
            # list images that aren't on s3
            for j, s3_image in enumerate(s3_image_list):
                if s3_image == "NA":
                    static_images_to_generate += [static_image_list[j]]
                    images_for_static_image_generation += [for_static_image_list[j]]
                    layout_for_static_image_generation += [layout] 


    return (
        images_to_download,
        images_to_generate,
        parquets_for_image_generation,
        layout_for_image_generation,
        static_images_to_generate,
        images_for_static_image_generation,
        layout_for_static_image_generation,
        video_frame_lists,
        video_names,
        parquets_to_download_or_generate,
        parquets_to_download,
        date_dict
    )


def find_start_date(end_date, interval):
    """Uses interval to get start date"""
    num, unit = re.match(r"(\d+)([A-Za-z]+)", interval).groups()
    if unit == "d":
        return end_date - relativedelta(days=int(num))
    elif unit == "w":
        return end_date - relativedelta(weeks=int(num))
    elif unit == "m":
        return end_date - relativedelta(months=int(num))
    elif unit == "y":
        return end_date - relativedelta(years=int(num))
    else:
        raise ValueError(f"Invalid interval format")


def video_label(interval):
    """Converts interval code into a readable string"""
    num, unit = re.match(r"(\d+)([A-Za-z]+)", interval).groups()
    num = int(num)
    if unit == "d":
        if num == 1:
            return "last-day"
        else:
            return "last-" + str(num) + "-days"
    elif unit == "w":
        if num == 1:
            return "last-week"
        else:
            return "last-" + str(num) + "-weeks"
    elif unit == "m":
        if num == 1:
            return "last-month"
        else:
            return "last-" + str(num) + "-months"
    elif unit == "y":
        if num == 1:
            return "last-year"
        else:
            return "last-" + str(num) + "-years"
    else:
        raise ValueError(f"Invalid interval format")