
def ff_line(path: str) -> str:
    """Cleans up path for ffmpeg."""
    
    escaped = path.replace("'", "'\\''")
    return f"file '../{escaped}'\n"

def generate_frame_list(image_list, framerate, frame_list):
    """Generates a text file with image names and durations for ffmpeg

    Parameters
    ----------
    mage_list: list of strings
        list of the filepaths of the images used for the video
    framerate: integer
        frame rate of the video in frames per second
    frame_list: string
        filepath to the text file that holds the list of frames and directions
   
    Returns
    -------
        Saved file of the image frames and durations

    """

    dur = 1.0 / float(framerate)

    with open(frame_list, "w", encoding="utf-8") as f:
            for image in image_list:
                f.write(ff_line(image))
                f.write(f"duration {dur}\n")
            # Repeat last file without a duration
            f.write(ff_line(image_list[-1]))

if __name__ == "__main__":
    framerate = snakemake.params["framerate"]
    image_list = snakemake.input["image_list"]
    frame_list = snakemake.output["frame_list"]

    generate_frame_list(image_list, framerate, frame_list)



        
