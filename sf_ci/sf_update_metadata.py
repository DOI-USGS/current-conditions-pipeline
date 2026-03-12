import os
import argparse
import boto3
import pandas as pd
from io import StringIO
from datetime import date, timedelta

# --- Config ---
BUCKET = "water-visualizations-prod-website"
METADATA_KEY = "visualizations/current_conditions/streamflow/sf_file_metadata.csv"
EXPECTED_OUTPUTS = {
    "parquet_file": "sf_ci/data/sf_categorizations_{date}.parquet",
    "desktop_CONUS_image_file": "sf_ci/figures/sf-{date}.png",
    "movie_3d": "sf_ci/movies/sf-{date}-back-3d.mp4",
    "movie_5d": "sf_ci/movies/sf-{date}-back-5d.mp4",
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
    except s3_client.exceptions.ClientError:
        return False


s3 = boto3.client("s3")

# Read or initialize metadata
try:
    obj = s3.get_object(Bucket=BUCKET, Key=METADATA_KEY)
    meta = pd.read_csv(obj["Body"])
except s3.exceptions.NoSuchKey:
    meta = pd.DataFrame(columns=["date"] + list(EXPECTED_OUTPUTS.keys()))

# Dates to update: any with gaps, plus date_of_interest
incomplete = meta[meta.drop(columns="date").isin(["NA"]).any(axis=1)]["date"].tolist()
dates_to_check = set(incomplete) | {str(date_of_interest)}

for d in dates_to_check:
    row = {"date": d}
    for col, key_template in EXPECTED_OUTPUTS.items():
        key = key_template.format(date=d)
        row[col] = key if key_exists(s3, BUCKET, key) else "NA"
    meta = meta[meta["date"] != d]
    meta = pd.concat([meta, pd.DataFrame([row])], ignore_index=True)

meta = meta.sort_values("date").reset_index(drop=True)

# Write back
buf = StringIO()
meta.to_csv(buf, index=False)
s3.put_object(Bucket=BUCKET, Key=METADATA_KEY, Body=buf.getvalue())
