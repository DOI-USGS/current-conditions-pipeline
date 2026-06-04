import os
import argparse
import boto3
import pandas as pd
import numpy
from io import StringIO
from datetime import date, timedelta


# --- Config ---
BUCKET = "water-visualizations-prod-website"
SF_PATH = "visualizations/current_conditions/streamflow/"
METADATA_KEY = "metadata/sf_file_metadata.csv"
EXPECTED_OUTPUTS = {
    "parquet_file": "data/sf_categorizations_{date}.parquet",
    "desktop_CONUS_OCONUS_image_file": "images/sf-desktop-CONUS_OCONUS-{date}.webp",
    "desktop_static_CONUS_OCONUS_image_file": "images/sf-static-CONUS_OCONUS-{date}.png",
    "desktop_CONUS_image_file": "images/sf-desktop-CONUS-{date}.webp",
    "desktop_AK_image_file": "images/sf-desktop-AK-{date}.webp",
    "desktop_AL_image_file": "images/sf-desktop-AL-{date}.webp",
    "desktop_AR_image_file": "images/sf-desktop-AR-{date}.webp",
    "desktop_AS_image_file": "images/sf-desktop-AS-{date}.webp",
    "desktop_AZ_image_file": "images/sf-desktop-AZ-{date}.webp",
    "desktop_CA_image_file": "images/sf-desktop-CA-{date}.webp",
    "desktop_CO_image_file": "images/sf-desktop-CO-{date}.webp",
    "desktop_CT_image_file": "images/sf-desktop-CT-{date}.webp",
    "desktop_DC_image_file": "images/sf-desktop-DC-{date}.webp",
    "desktop_DE_image_file": "images/sf-desktop-DE-{date}.webp",
    "desktop_FL_image_file": "images/sf-desktop-FL-{date}.webp",
    "desktop_GA_image_file": "images/sf-desktop-GA-{date}.webp",
    "desktop_GU_MP_image_file": "images/sf-desktop-GU_MP-{date}.webp",
    "desktop_HI_image_file": "images/sf-desktop-HI-{date}.webp",
    "desktop_IA_image_file": "images/sf-desktop-IA-{date}.webp",
    "desktop_ID_image_file": "images/sf-desktop-ID-{date}.webp",
    "desktop_IL_image_file": "images/sf-desktop-IL-{date}.webp",
    "desktop_IN_image_file": "images/sf-desktop-IN-{date}.webp",
    "desktop_KS_image_file": "images/sf-desktop-KS-{date}.webp",
    "desktop_KY_image_file": "images/sf-desktop-KY-{date}.webp",
    "desktop_LA_image_file": "images/sf-desktop-LA-{date}.webp",
    "desktop_MA_image_file": "images/sf-desktop-MA-{date}.webp",
    "desktop_MD_image_file": "images/sf-desktop-MD-{date}.webp",
    "desktop_ME_image_file": "images/sf-desktop-ME-{date}.webp",
    "desktop_MI_image_file": "images/sf-desktop-MI-{date}.webp",
    "desktop_MN_image_file": "images/sf-desktop-MN-{date}.webp",
    "desktop_MO_image_file": "images/sf-desktop-MO-{date}.webp",
    "desktop_MS_image_file": "images/sf-desktop-MS-{date}.webp",
    "desktop_MT_image_file": "images/sf-desktop-MT-{date}.webp",
    "desktop_NC_image_file": "images/sf-desktop-NC-{date}.webp",
    "desktop_ND_image_file": "images/sf-desktop-ND-{date}.webp",
    "desktop_NE_image_file": "images/sf-desktop-NE-{date}.webp",
    "desktop_NH_image_file": "images/sf-desktop-NH-{date}.webp",
    "desktop_NJ_image_file": "images/sf-desktop-NJ-{date}.webp",
    "desktop_NM_image_file": "images/sf-desktop-NM-{date}.webp",
    "desktop_NV_image_file": "images/sf-desktop-NV-{date}.webp",
    "desktop_NY_image_file": "images/sf-desktop-NY-{date}.webp",
    "desktop_OH_image_file": "images/sf-desktop-OH-{date}.webp",
    "desktop_OK_image_file": "images/sf-desktop-OK-{date}.webp",
    "desktop_OR_image_file": "images/sf-desktop-OR-{date}.webp",
    "desktop_PA_image_file": "images/sf-desktop-PA-{date}.webp",
    "desktop_PR_VI_image_file": "images/sf-desktop-PR_VI-{date}.webp",
    "desktop_RI_image_file": "images/sf-desktop-RI-{date}.webp",
    "desktop_SC_image_file": "images/sf-desktop-SC-{date}.webp",
    "desktop_SD_image_file": "images/sf-desktop-SD-{date}.webp",
    "desktop_TN_image_file": "images/sf-desktop-TN-{date}.webp",
    "desktop_TX_image_file": "images/sf-desktop-TX-{date}.webp",
    "desktop_UT_image_file": "images/sf-desktop-UT-{date}.webp",
    "desktop_VA_image_file": "images/sf-desktop-VA-{date}.webp",
    "desktop_VT_image_file": "images/sf-desktop-VT-{date}.webp",
    "desktop_WA_image_file": "images/sf-desktop-WA-{date}.webp",
    "desktop_WI_image_file": "images/sf-desktop-WI-{date}.webp",
    "desktop_WV_image_file": "images/sf-desktop-WV-{date}.webp",
    "desktop_WY_image_file": "images/sf-desktop-WY-{date}.webp",
    "mobile_CONUS_image_file": "images/sf-mobile-CONUS-{date}.webp",
    "mobile_AK_image_file": "images/sf-mobile-AK-{date}.webp",
    "mobile_AL_image_file": "images/sf-mobile-AL-{date}.webp",
    "mobile_AR_image_file": "images/sf-mobile-AR-{date}.webp",
    "mobile_AS_image_file": "images/sf-mobile-AS-{date}.webp",
    "mobile_AZ_image_file": "images/sf-mobile-AZ-{date}.webp",
    "mobile_CA_image_file": "images/sf-mobile-CA-{date}.webp",
    "mobile_CO_image_file": "images/sf-mobile-CO-{date}.webp",
    "mobile_CT_image_file": "images/sf-mobile-CT-{date}.webp",
    "mobile_DC_image_file": "images/sf-mobile-DC-{date}.webp",
    "mobile_DE_image_file": "images/sf-mobile-DE-{date}.webp",
    "mobile_FL_image_file": "images/sf-mobile-FL-{date}.webp",
    "mobile_GA_image_file": "images/sf-mobile-GA-{date}.webp",
    "mobile_GU_MP_image_file": "images/sf-mobile-GU_MP-{date}.webp",
    "mobile_HI_image_file": "images/sf-mobile-HI-{date}.webp",
    "mobile_IA_image_file": "images/sf-mobile-IA-{date}.webp",
    "mobile_ID_image_file": "images/sf-mobile-ID-{date}.webp",
    "mobile_IL_image_file": "images/sf-mobile-IL-{date}.webp",
    "mobile_IN_image_file": "images/sf-mobile-IN-{date}.webp",
    "mobile_KS_image_file": "images/sf-mobile-KS-{date}.webp",
    "mobile_KY_image_file": "images/sf-mobile-KY-{date}.webp",
    "mobile_LA_image_file": "images/sf-mobile-LA-{date}.webp",
    "mobile_MA_image_file": "images/sf-mobile-MA-{date}.webp",
    "mobile_MD_image_file": "images/sf-mobile-MD-{date}.webp",
    "mobile_ME_image_file": "images/sf-mobile-ME-{date}.webp",
    "mobile_MI_image_file": "images/sf-mobile-MI-{date}.webp",
    "mobile_MN_image_file": "images/sf-mobile-MN-{date}.webp",
    "mobile_MO_image_file": "images/sf-mobile-MO-{date}.webp",
    "mobile_MS_image_file": "images/sf-mobile-MS-{date}.webp",
    "mobile_MT_image_file": "images/sf-mobile-MT-{date}.webp",
    "mobile_NC_image_file": "images/sf-mobile-NC-{date}.webp",
    "mobile_ND_image_file": "images/sf-mobile-ND-{date}.webp",
    "mobile_NE_image_file": "images/sf-mobile-NE-{date}.webp",
    "mobile_NH_image_file": "images/sf-mobile-NH-{date}.webp",
    "mobile_NJ_image_file": "images/sf-mobile-NJ-{date}.webp",
    "mobile_NM_image_file": "images/sf-mobile-NM-{date}.webp",
    "mobile_NV_image_file": "images/sf-mobile-NV-{date}.webp",
    "mobile_NY_image_file": "images/sf-mobile-NY-{date}.webp",
    "mobile_OH_image_file": "images/sf-mobile-OH-{date}.webp",
    "mobile_OK_image_file": "images/sf-mobile-OK-{date}.webp",
    "mobile_OR_image_file": "images/sf-mobile-OR-{date}.webp",
    "mobile_PA_image_file": "images/sf-mobile-PA-{date}.webp",
    "mobile_PR_VI_image_file": "images/sf-mobile-PR_VI-{date}.webp",
    "mobile_RI_image_file": "images/sf-mobile-RI-{date}.webp",
    "mobile_SC_image_file": "images/sf-mobile-SC-{date}.webp",
    "mobile_SD_image_file": "images/sf-mobile-SD-{date}.webp",
    "mobile_TN_image_file": "images/sf-mobile-TN-{date}.webp",
    "mobile_TX_image_file": "images/sf-mobile-TX-{date}.webp",
    "mobile_UT_image_file": "images/sf-mobile-UT-{date}.webp",
    "mobile_VA_image_file": "images/sf-mobile-VA-{date}.webp",
    "mobile_VT_image_file": "images/sf-mobile-VT-{date}.webp",
    "mobile_WA_image_file": "images/sf-mobile-WA-{date}.webp",
    "mobile_WI_image_file": "images/sf-mobile-WI-{date}.webp",
    "mobile_WV_image_file": "images/sf-mobile-WV-{date}.webp",
    "mobile_WY_image_file": "images/sf-mobile-WY-{date}.webp",
}

parser = argparse.ArgumentParser()
parser.add_argument("--date", required=True)
args = parser.parse_args()

date_of_interest = date.fromisoformat(args.date)
# if os.environ.get("IS_FINAL_RUN") == "true":
#     date_of_interest -= timedelta(days=1)


def list_existing_keys(s3_client, bucket, prefix):
    """List all keys under a prefix, handling pagination."""
    keys = set()
    paginator = s3_client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            keys.add(obj["Key"])
    return keys

s3 = boto3.client("s3")

# Read or initialize metadata
try:
    obj = s3.get_object(Bucket=BUCKET, Key=SF_PATH + METADATA_KEY)
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

existing_keys = list_existing_keys(s3, BUCKET, SF_PATH)

for d in dates_to_check:
    row = {"date": d}
    for col, key_template in EXPECTED_OUTPUTS.items():
        key = SF_PATH + key_template.format(date=d)
        row[col] = key_template.format(date=d) if key in existing_keys else "NA"
    meta = meta[meta["date"] != d]
    meta = pd.concat([meta, pd.DataFrame([row])], ignore_index=True)

meta = meta.sort_values("date").reset_index(drop=True)

# Write back
buf = StringIO()
meta.to_csv(buf, index=False)
s3.put_object(Bucket=BUCKET, Key=SF_PATH + METADATA_KEY, Body=buf.getvalue())
