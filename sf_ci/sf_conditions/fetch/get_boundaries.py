from pygris import states
from pygris import counties
import geopandas as gpd

def get_boundaries(
        resolution,
        year,
        conus_geojson,
        ak_geojson,
        hi_geojson,
        prvi_geojson,
        gump_geojson,
        as_geojson,
):
    """Gets boundary geometry from Census data

    Parameters
    ----------
    resolution: string
        resolution of the census daa
    year: integer
        year of the census data
    conus_geojson: string
        filepath and name of .geojson file for conus
    ak_geojson: string
        filepath and name of .geojson file for alaska
    hi_geojson: string
        filepath and name of .geojson file for hawaii
    prvi_geojson: string
        filepath and name of .geojson file for puerto rico and the virgin islands
    gump_geojson: string
        filepath and name of .geojson file for the mariana islands
    as_geojson: string
        filepath and name of .geojson file for american somoa 

    Returns
    -------
        Saved geometries as .geojson files

    """

    us = states(cb=True, resolution=resolution, year=year)

    exclude_for_conus = {"AK", "HI", "PR", "VI", "GU", "MP", "AS"}
    conus_gpd = us[~us["STUSPS"].isin(exclude_for_conus)]
    ak_gpd = us[us["STUSPS"] == "AK"]
    hi_gpd = us[us["STUSPS"] == "HI"]
    prvi_gpd = us[us["STUSPS"].isin(["PR", "VI"])]
    gump_gpd = us[us["STUSPS"].isin(["GU", "MP"])]

    # exclude swains island and rose island
    as_cnty = counties(state="AS",cb=True, resolution=resolution, year=year)
    as_no_swains = as_cnty[~as_cnty["NAME"].isin(["Swains Island", "Rose Island"])]
    as_gpd = gpd.GeoDataFrame({"geometry": [as_no_swains.union_all()]}, crs=us.crs)

    conus_gpd.to_file(conus_geojson)
    ak_gpd.to_file(ak_geojson)
    hi_gpd.to_file(hi_geojson)
    prvi_gpd.to_file(prvi_geojson)
    gump_gpd.to_file(gump_geojson)
    as_gpd.to_file(as_geojson)

if __name__ == "__main__":
    resolution = snakemake.params["resolution"]
    year = snakemake.params["year"]

    conus_geojson = snakemake.output["conus_geojson"]
    ak_geojson = snakemake.output["ak_geojson"]
    hi_geojson = snakemake.output["hi_geojson"]
    prvi_geojson = snakemake.output["prvi_geojson"]
    gump_geojson = snakemake.output["gump_geojson"]
    as_geojson = snakemake.output["as_geojson"]

    get_boundaries(
        resolution,
        year,
        conus_geojson,
        ak_geojson,
        hi_geojson,
        prvi_geojson,
        gump_geojson,
        as_geojson,
    )
