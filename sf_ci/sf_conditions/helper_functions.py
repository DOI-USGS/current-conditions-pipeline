import os
import re
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta


def generate_image_list(end_date_str, intervals, metadata, column = 'desktop_CONUS_image_file'):
    """Generates the list of images."""
    max_delta = timedelta(0)
    image_lists = []
    for interval in intervals:
        # Date to run based on argument to Snakemake
        # Use snakemake --cores all --config date="YYYY-MM-DD"
        end_date = datetime.strptime(end_date_str,"%Y-%m-%d").date()
        start_date = find_start_date(end_date, interval)
        delta = end_date - start_date

        # Generate list of dates
        date_list = []
        current = start_date
        while current <= end_date:
            date_list.append(current.strftime("%Y-%m-%d"))
            current += timedelta(days=1)

        image_list = ["figures/sf-" + str(date)+ ".png" for date in date_list]
        image_lists += [image_list]

        # this list is from the maxiumum interval
        if delta > max_delta:
            max_delta = delta

            s3_image_list = metadata[metadata['date'].isin(date_list)][column].tolist()
            parquet_list = metadata[metadata['date'].isin(date_list)]["parquet_file"].tolist()

            image_download_list = []
            image_make_list = []
            parquet_make_list = []
            for j, s3_image in enumerate(s3_image_list):
                if s3_image == 'NA':
                    parquet_make_list += [parquet_list[j]]
                    image_make_list += [image_list[j]]
                else:
                    image_download_list += [image_list[j]]

    return image_lists, image_download_list, image_make_list, parquet_make_list

def find_start_date(end_date, interval):
    num, unit = re.match(r"(\d+)([A-Za-z]+)", interval).groups()
    if unit == "d":
        return (end_date - relativedelta(days=int(num)))
    elif unit == "w":
        return (end_date - relativedelta(weeks=int(num)))
    elif unit == "m":
        return (end_date - relativedelta(months=int(num)))
    elif unit == "y":
        return (end_date - relativedelta(years=int(num)))
    else:
        raise ValueError(f"Invalid interval format")