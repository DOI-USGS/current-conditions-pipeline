from sf_conditions.plot.plot_functions import make_legend_images

if __name__ == "__main__":
    marker_params = snakemake.params["marker_params"]
    dpi = snakemake.params["dpi"]

    make_legend_images(
        marker_params,
        dpi
    )
