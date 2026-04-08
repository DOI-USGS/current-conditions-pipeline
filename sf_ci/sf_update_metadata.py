import os
import argparse
import boto3
import pandas as pd
import numpy
from io import StringIO
from datetime import date, timedelta
from botocore.exceptions import ClientError

# --- Config ---
BUCKET = "water-visualizations-prod-website"
METADATA_KEY = "streamflow/metadata/sf_file_metadata.csv"
EXPECTED_OUTPUTS = {
    "parquet_file": "streamflow/data/sf_categorizations_{date}.parquet",
    "mobile_CONUS_image_file": "streamflow/images/sf-mobile-CONUS-{date}.png",
    "mobile_AK_image_file": "streamflow/images/sf-mobile-AK-{date}.png",
    "mobile_HI_image_file": "streamflow/images/sf-mobile-HI-{date}.png",
    "mobile_PR_VI_image_file": "streamflow/images/sf-mobile-PR_VI-{date}.png",
    "mobile_GU_MP_image_file": "streamflow/images/sf-mobile-GU_MP-{date}.png",
    "mobile_AS_image_file": "streamflow/images/sf-mobile-AS-{date}.png",
    "desktop_CONUS_OCONUS_image_file": "streamflow/images/sf-desktop-CONUS_OCONUS-{date}.png",
    "movie_3d": "streamflow/videos/sf-movie-{date}-back-3d.mp4",
    "movie_5d": "streamflow/videos/sf-movie-{date}-back-5d.mp4",
}

parser = argparse.ArgumentParser()
parser.add_argument("--date", required=True)
args = parser.parse_args()

date_of_interest = date.fromisoformat(args.date)
if os.environ.get("IS_FINAL_RUN") == "true":
    date_of_interest -= timedelta(days=1)


def key_exists(s3_client, bucket, key):
    try:
        s3_client.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] in ("404", "NoSuchKey"):
            return False
        raise  # re-raise unexpected errors (auth, etc.)

s3 = boto3.client("s3")

# Read or initialize metadata
try:
    obj = s3.get_object(Bucket=BUCKET, Key=METADATA_KEY)
    meta = pd.read_csv(obj["Body"], dtype=str, keep_default_na=False)
    meta = meta.loc[:, ~meta.columns.str.startswith("Unnamed")]
except s3.exceptions.NoSuchKey:
    meta = pd.DataFrame(columns=["date"] + list(EXPECTED_OUTPUTS.keys()))

# ensure date column is in YYYY-MM-DD format
meta["date"] = pd.to_datetime(meta["date"], format="mixed").dt.strftime("%Y-%m-%d")

# Dates to update: any with gaps, plus date_of_interest, and range between max date and date_of_interest
incomplete = meta[meta.drop(columns="date").isin(["NA", "", numpy.nan, None]).any(axis=1)][
    "date"
].tolist()

# Convert max date and date_of_interest to datetime for range calculation
start_date = pd.to_datetime(meta["date"].max())
end_date = pd.to_datetime(date_of_interest)

# Generate range of dates between max(meta) and date_of_interest (inclusive)
# We use +1 day to start from the day after the current max date
if end_date > start_date:
    missing_dates = pd.date_range(
        start=start_date + timedelta(days=1), 
        end=end_date
    ).strftime("%Y-%m-%d").tolist()
else:
    missing_dates = []

dates_to_check = set(incomplete) | {str(date_of_interest)} | set(missing_dates)

print(f"Checking dates: {dates_to_check}")

for d in dates_to_check:
    row = {"date": d}
    for col, key_template in EXPECTED_OUTPUTS.items():
        key = key_template.format(date=d)
        # print(f"[{col}] s3://{BUCKET}/{key} → {'FOUND' if exists else 'MISSING'}", flush=True)
        row[col] = key if key_exists(s3, BUCKET, key) else "NA"
    meta = meta[meta["date"] != d]
    meta = pd.concat([meta, pd.DataFrame([row])], ignore_index=True)

meta = meta.sort_values("date").reset_index(drop=True)

# Write back
buf = StringIO()
meta.to_csv(buf, index=False)
s3.put_object(Bucket=BUCKET, Key=METADATA_KEY, Body=buf.getvalue())
