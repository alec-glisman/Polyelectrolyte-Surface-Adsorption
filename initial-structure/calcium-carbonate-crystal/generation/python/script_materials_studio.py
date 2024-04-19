import os
import sys
from pathlib import Path
import numpy as np

sys.path.append(os.path.dirname(os.path.realpath(sys.argv[0])) + "/src")

# local import
from miller import conv_hex_to_cubic_idx  # noqa: E402
from surface import clean_pdb, replicates, replicate_pdb  # noqa: E402


def main() -> None:
    sizes = np.arange(1, 15)  # [nm] surface sizes

    # input files
    dir_file = Path(f"{__file__}").parent
    dir_base = dir_file.parent / "materials-studio/pdb"
    pdb_files = sorted(list(dir_base.glob("*.pdb")))

    # output files
    dir_output = dir_file / "output"
    dir_output.mkdir(exist_ok=True)

    for pdb_file in pdb_files:
        polymorph = pdb_file.stem.split(" ")[0]

        index_group = pdb_file.stem.split(" ")[1:]
        miller_indices = [int(index.strip("()")) for index in index_group]
        print(f"Polymorph: {polymorph}, Miller indices: {miller_indices}")

        for size in sizes:
            if len(miller_indices) == 4:
                miller_out = conv_hex_to_cubic_idx(miller_indices)
            else:
                miller_out = miller_indices

            output_pdb = dir_output / f"{polymorph}-{"".join(map(str, miller_out))}surface-{size}nm.pdb"
            clean_pdb(pdb_file, output_pdb)
            cell_replicates = replicates(output_pdb, size)
            print(f"  Size: {size} nm, Replicates: {cell_replicates}")

            replicate_pdb(output_pdb, cell_replicates)


if __name__ == "__main__":
    main()
