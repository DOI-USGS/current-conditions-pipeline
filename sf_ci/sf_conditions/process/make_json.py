import json

def make_json(date_dict ,output):
    with open(output, "w", encoding="utf-8") as f:
        f.write("{\n")
        items = list(date_dict.items())
        for i, (k, v) in enumerate(items):
            comma = "," if i < len(items) - 1 else ""
            # keys pretty, values compact (arrays on one line)
            f.write(f'  {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, separators=(",", ":"), ensure_ascii=False)}{comma}\n')
        f.write("}")



if __name__ == "__main__":
    date_dict = snakemake.params["date_dict"]
    output = snakemake.output["output"]

    make_json(date_dict , output)