
def ff_line(path: str) -> str:
    # Escape single quotes for ffmpeg concat list format: 'foo' -> '\''foo'\''
    escaped = path.replace("'", "'\\''")
    return f"file '../{escaped}'\n"

def generate_frame_list(image_list, framerate, frame_list):
    # Compute duration from framerate
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



        
