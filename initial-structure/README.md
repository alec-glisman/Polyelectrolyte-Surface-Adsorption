# Initial configurations

## Calcium Carbonate Crystal

The initial structures of calcite, aragonite, and vaterite unit cells were collected from the American Minerologist Crystal Structure Database.
All three structures were determined by X-ray diffraction and have been published in the literature.
Further information and citations can be found inside the directory for each structure.

The unit cells are then converted into surfaces using the [`pymatgen`](https://pymatgen.org/) package.
Pymatgen (Python Materials Genomics) is a robust, open-source Python library for materials analysis.
As of September 2022, we have not yet implemented the conversion of unit cells into surfaces using in our scripts, but an example method can be found in a [Jupyter notebook here](calcium-carbonate-crystal/python/surface.ipynb)

## Polyelectrolyte

Initial configurations were generated using a combination of ChemDraw, CHARMM-GUI, and Avogadro applications.

For poly(alpha-aspartic acid) and poly(alpha-glutamic acid), initial configurations were directly made in Avogadro.
The "alpha" moniker denotes that the monomer-monomer bonds are peptide bonds.
The peptide building is located in the top bar menu: `Build --> Insert --> Peptide ...`.
Avogadro can create initial configurations for different stereoisomers (L vs. D), structures (straight chain, alpha helix, etc), N and C terminal groups.
However, Avogadro cannot create configurations for different regioisomers directly.
These poly(amino acids) have different regioisomers and stereoisomers, as seen in below.

<img src="pictures/poly-glutamic-acid-regioisomers.png" alt="Poly(glutamic acid) regioisomers" style="width:900px;"/>

[_Progress in Polymer Science_ 113 (**2021**) 101341](https://doi.org/10.1016/j.progpolymsci.2020.101341)

<img src="pictures/poly-aspartic-acid-regio-steroisomers.png" alt="Poly(glutamic acid) regio and stereoisomers" style="width:600px;"/>

[_European Polymer Journal_ 59 (**2014**) 363–376](https://doi.org/10.1016/j.eurpolymj.2014.07.043)

Regioisomers are created in ChemDraw and then exported as `MDL Molfile V3000`.
This generates a `.mol` file that can be read into Avogadro.
ChemDraw exports identity and topology information, but not Cartesian configuration coordinates.
Avogadro can create coordinates from the given information.

Avogadro structures are then exported to `.pdb` format to be read into GROMACS.
Further preprocessing may be necessary so that the given force field can recognize the input residues.
The configurations are found in the `initial-configuration` directory.

Poly(acrylic acid) initial configurations are generated with the CHARMM-GUI website for atactic, ionized acrylic acid monomers.
This yields an input `.pdb` structure that is then geometry optimized and energy minimized in Avogadro.
