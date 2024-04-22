"""
This script generates the surface of the calcium carbonate crystal using the
PDB outputs from the Materials Studio software.

Author: Alec Glisman (GitHub: alec-glisman)
Date: 2024-04-22
"""

import os
import sys
from pathlib import Path
import numpy as np

sys.path.append(os.path.dirname(os.path.realpath(sys.argv[0])) + "/src")

# local import
from miller import conv_hex_to_cubic_idx  # noqa: E402
from surface import clean_pdb, replicates, replicate_pdb  # noqa: E402


def main() -> None:
    """
    Main function to generate surface structures of calcium carbonate crystal.

    This script generates surface structures of calcium carbonate crystal using
    input PDB files and replicates them to different sizes. The generated structures
    are saved as PDB files in the output directory.

    The script takes the following steps:
    1. Reads the input PDB files from the materials-studio/pdb directory.
    2. Creates an output directory to save the generated surface structures.
    3. For each input PDB file, it extracts the polymorph and Miller indices.
    4. Cleans the PDB file and saves it as the unit cell structure.
    5. Generates surface structures of different sizes by replicating the unit cell.
    6. Saves the replicated structures as PDB files in the output directory.

    The sizes of the surface structures are defined by the 'sizes' array, which
    contains the desired surface sizes in nanometers.

    Note: This script requires the 'miller' and 'surface' modules.

    Returns:
        None
    """
    sizes = np.arange(1, 16)  # [nm] surface sizes

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
        if len(miller_indices) == 4:
            miller_out = conv_hex_to_cubic_idx(miller_indices)
            print(f"Hexagonal indices: {miller_indices}, Cubic indices: {miller_out}")
        else:
            miller_out = miller_indices

        print(f"Polymorph: {polymorph}, Miller indices: {miller_indices}")

        # unit cell
        output_filename = f"{polymorph}-{''.join(map(str, miller_out))}surface"
        output_pdb = dir_output / f"{output_filename}-unitcell.pdb"
        clean_pdb(pdb_file, output_pdb)

        for size in sizes:

            output_pdb = dir_output / f"{output_filename}-{size}nm.pdb"
            clean_pdb(pdb_file, output_pdb)
            cell_replicates, box_dim = replicates(output_pdb, size)

            # if aragonite 110, double the z dimension
            if polymorph == "aragonite" and miller_out == [1, 1, 0]:
                cell_replicates[2] *= 2
                box_dim[2] *= 2

            box_dim = np.round(box_dim, 1)

            print(
                f"  Crystal length: {size} nm, Box dimension: {box_dim} nm"
                + f", Number of replicates: {cell_replicates}"
            )

            replicate_pdb(output_pdb, cell_replicates)


if __name__ == "__main__":
    main()
