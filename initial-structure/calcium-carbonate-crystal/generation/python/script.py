import os
import sys
from pathlib import Path
import numpy as np

sys.path.append(os.path.dirname(os.path.realpath(sys.argv[0])) + "/src")

# local import
from miller import conv_hex_to_cubic_idx  # noqa: E402
from surface import SurfaceProperties, SurfaceGen  # noqa: E402


def main() -> None:
    verbose = True
    crystal = {"calcite": {}, "aragonite": {}, "vaterite": {}}  # CaCO3 polymorphs

    for polymorph, properties in crystal.items():
        properties["sizes"] = np.arange(1, 15)  # [nm] surface sizes
        properties["file"] = Path(
            "./../american-mineralogist-crystal-structure-database"
            + f"/{polymorph}/AMS_DATA.cif"
        )

    dominant = SurfaceProperties(
        miller_indices=conv_hex_to_cubic_idx((1, 0, -1, 4)),
        surface_dim=(0.4988, 0.8094),
        n_layers=4,
        z_flip=False,
        z_translation=0,
    )
    co3_basal = SurfaceProperties(
        miller_indices=conv_hex_to_cubic_idx((0, 0, 0, 1)),
        surface_dim=(0.4988, 0.4988),
        n_layers=1,
        z_flip=False,
        z_translation=0,
    )
    crystal["calcite"]["crystals"] = [dominant, co3_basal]

    # # NOTE: slab-1 has the correct termination and polarity
    ca_cleavage = SurfaceProperties(
        miller_indices=(0, 1, 0),
        surface_dim=(0.4961, 0.7967),
        n_layers=2,
        z_flip=False,
        z_translation=0,
    )
    ca_twinning = SurfaceProperties(
        miller_indices=(1, 1, 0),
        surface_dim=(0.7967, 0.7587),
        n_layers=3,
        z_flip=False,
        z_translation=0,
    )
    co3_cleavage = SurfaceProperties(
        miller_indices=(0, 1, 1),
        surface_dim=(0.4961, 0.9820),
        n_layers=3,
        z_flip=False,
        z_translation=0,
    )
    crystal["aragonite"]["crystals"] = [ca_cleavage, ca_twinning, co3_cleavage]

    co3_dominant1 = SurfaceProperties(
        miller_indices=(0, 1, 0),
        surface_dim=(0.7290, 2.5302),
        n_layers=1,
        z_flip=False,
        z_translation=0,
    )
    co3_dominant2 = SurfaceProperties(
        miller_indices=(0, 1, 1),
        surface_dim=(0.729, 2.6331),
        n_layers=1,
        z_flip=False,
        z_translation=0,
    )
    ca_dominant = SurfaceProperties(
        miller_indices=(1, 0, 1),
        surface_dim=(0.729, 2.6331),
        n_layers=1,
        z_flip=False,
        z_translation=0,
    )
    crystal["vaterite"]["crystals"] = [co3_dominant1, co3_dominant2, ca_dominant]

    # iterate over polymorphs, Miller indices, and sizes
    for polymorph, properties in crystal.items():
        for cryst in properties["crystals"]:

            # export unit cell
            print(
                f"Polymorph: {polymorph}, Miller index: {cryst.miller_indices}"
                + ", Unit cell"
            )
            replicates = np.array([1, 1, 1])
            surf = SurfaceGen(
                properties["file"],
                cryst.miller_indices,
                cryst.n_layers,
                replicates,
                polymorph,
                verbose,
            )
            surf.run()

            # iterate over sizes
            for size in properties["sizes"]:
                print(
                    f"Polymorph: {polymorph}, Miller index: {cryst.miller_indices}"
                    + f", Size: {size} nm"
                )
                unit_dim = cryst.surface_dim
                replicates = np.array(
                    [
                        max(np.round(size / unit_dim[0]), 1),
                        max(np.round(size / unit_dim[1]), 1),
                        1,
                    ]
                )
                surf = SurfaceGen(
                    properties["file"],
                    cryst.miller_indices,
                    cryst.n_layers,
                    replicates,
                    polymorph,
                    verbose,
                )
                surf.run()


if __name__ == "__main__":
    main()
