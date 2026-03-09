from pygris import states


def get_conus(resolution, year, outfile):
    us = states(cb=True, resolution=resolution, year=year)
    us.to_file(outfile)


if __name__ == "__main__":
    resolution = snakemake.params["resolution"]
    year = snakemake.params["year"]
    outfile = snakemake.output["outfile"]

    get_conus(resolution, year, outfile)
