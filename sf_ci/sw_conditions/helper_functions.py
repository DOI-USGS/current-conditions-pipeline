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
