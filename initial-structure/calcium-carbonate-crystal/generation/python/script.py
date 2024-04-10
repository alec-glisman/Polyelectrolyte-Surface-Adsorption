import os
import sys
from pathlib import Path
import numpy as np

sys.path.append(os.path.dirname(os.path.realpath(sys.argv[0])) + "/src")

# local import
from miller import conv_hex_to_cubic_idx  # noqa: E402
from surface import SurfaceGen  # noqa: E402


def main() -> None:
    verbose = True
    crystal = {"calcite": {}, "aragonite": {}, "vaterite": {}}  # CaCO3 polymorphs

    for polymorph, properties in crystal.items():
        properties["sizes"] = np.arange(1, 15)  # [nm] surface sizes
        properties["thickness"] = 9  # [Å] slab thickness
        properties["file"] = Path(
            "./../american-mineralogist-crystal-structure-database"
            + f"/{polymorph}/AMS_DATA.cif"
        )

    crystal["calcite"]["miller"] = [
        conv_hex_to_cubic_idx((1, 0, -1, 4)),
        (0, 0, 1),
    ]
    crystal["calcite"]["unit_cell_dim"] = [
        (0.50, 0.81),
        (0.50, 0.43),
    ]  # [nm]

    crystal["aragonite"]["miller"] = ...
    crystal["aragonite"]["unit_cell_dim"] = ...

    crystal["vaterite"]["miller"] = ...
    crystal["vaterite"]["unit_cell_dim"] = ...

    # iterate over polymorphs, Miller indices, and sizes
    for polymorph, properties in crystal.items():
        for j, idx in enumerate(properties["miller"]):

            # export unit cell
            print(f"Polymorph: {polymorph}, Miller index: {idx}, Unit cell")
            replicates = np.array([1, 1, 1])
            surf = SurfaceGen(
                properties["file"],
                idx,
                replicates,
                properties["thickness"],
                polymorph,
                verbose,
            )
            surf.run()

            # iterate over sizes
            for size in properties["sizes"]:
                print(f"Polymorph: {polymorph}, Miller index: {idx}, Size: {size} nm")
                unit_dim = properties["unit_cell_dim"][j]
                replicates = np.array(
                    [np.round(size / unit_dim[0]), np.round(size / unit_dim[1]), 1]
                )
                surf = SurfaceGen(
                    properties["file"],
                    idx,
                    replicates,
                    properties["thickness"],
                    polymorph,
                    verbose,
                )
                surf.run()


if __name__ == "__main__":
    main()
