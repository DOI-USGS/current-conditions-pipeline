from pygris import states
from pygris import counties
import geopandas as gpd

STATES_50_DC = [
    'AL','AK','AZ','AR','CA','CO','CT','DC','DE','FL','GA','HI','ID','IL','IN',
    'IA','KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH',
    'NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT',
    'VT','VA','WA','WV','WI','WY'
]

def get_boundaries(resolution, year, output):
    """Gets boundary geometry from Census data and saves as geojson files."""

    us = states(cb=True, resolution=resolution, year=year)

    # Regional groupings
    exclude_for_conus = {"AK", "HI", "PR", "VI", "GU", "MP", "AS"}
    conus_gpd = us[~us["STUSPS"].isin(exclude_for_conus)]
    prvi_gpd = us[us["STUSPS"].isin(["PR", "VI"])]
    gump_gpd = us[us["STUSPS"].isin(["GU", "MP"])]

    # American Samoa - exclude Swains Island and Rose Island
    as_cnty = counties(state="AS", cb=True, resolution=resolution, year=year)
    as_no_swains = as_cnty[~as_cnty["NAME"].isin(["Swains Island", "Rose Island"])]
    as_gpd = gpd.GeoDataFrame({"geometry": [as_no_swains.union_all()]}, crs=us.crs)

    # Save regional files
    conus_gpd.to_file(output["conus_geojson"])
    prvi_gpd.to_file(output["prvi_geojson"])
    gump_gpd.to_file(output["gump_geojson"])
    as_gpd.to_file(output["as_geojson"])

    # Save individual state/DC files
    for st in STATES_50_DC:
        key = st.lower() + "_geojson"
        if key in output.keys():
            st_gpd = us[us["STUSPS"] == st]
            st_gpd.to_file(output[key])


if __name__ == "__main__":
    resolution = snakemake.params["resolution"]
    year = snakemake.params["year"]

    get_boundaries(resolution, year, snakemake.output)
