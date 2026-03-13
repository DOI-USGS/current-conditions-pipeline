from pygris import states

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
    us = states(cb=False, resolution=resolution, year=year)

    exclude_for_conus = {"AK", "HI", "PR", "VI", "GU", "MP", "AS"}
    conus_gpd = us[~us["STUSPS"].isin(exclude_for_conus)]
    ak_gpd = us[us["STUSPS"] == "AK"]
    hi_gpd = us[us["STUSPS"] == "HI"]
    prvi_gpd = us[us["STUSPS"].isin(["PR", "VI"])]
    gump_gpd = us[us["STUSPS"].isin(["GU", "MP"])]
    as_gpd = us[us["STUSPS"] == "AS"]

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
