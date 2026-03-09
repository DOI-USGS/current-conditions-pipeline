import os
from datetime import datetime, timedelta


def generate_date_list(start_date, end_date):
    """Generates the list of dates given a start and end date."""

    # Parse input strings into datetime objects
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = datetime.strptime(end_date, "%Y-%m-%d")

    # Generate list of dates
    date_list = []
    current = start
    while current <= end:
        date_list.append(current.strftime("%Y-%m-%d"))
        current += timedelta(days=1)

    return date_list

def strip_date_list(filepath_list, prefix = "sf_categorizations_", suffix = ".parquet"):
    """Takes a list of parquet files with dates and makes a list of just the dates"""

    date_list = []
    for filepath in filepath_list:
        dirname = os.path.dirname(filepath)

        date = filepath[len(dirname) + 1 + len(prefix): - len(suffix)]
        date_list += [date]

    return date_list