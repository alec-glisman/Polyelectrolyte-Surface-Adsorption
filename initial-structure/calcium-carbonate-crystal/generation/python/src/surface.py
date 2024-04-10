import os
from pathlib import Path
import warnings

import MDAnalysis as mda
from MDAnalysis import transformations
import numpy as np
from openbabel import openbabel as ob
from pymatgen.core.structure import Structure
from pymatgen.core.surface import SlabGenerator, Slab
from pymatgen.symmetry.analyzer import SpacegroupAnalyzer


class SurfaceGen:

    def __init__(
        self,
        crystal_file: Path,
        miller_indices: np.array,
        replicates: np.array,
        slab_thickness: float,
        filename: Path,
        verbose: bool = False,
    ):
        self.crystal_file: Path = crystal_file
        self.miller_indices: np.array = miller_indices
        self.replicates: np.array = replicates
        self.slab_thickness: float = slab_thickness
        self.filename: Path = filename
        self.verbose: bool = verbose

        self.unit_cell: Structure = None
        self.space_group: SpacegroupAnalyzer = None
        self.generator: SlabGenerator = None
        self.slabs: list[Slab] = None

    def run(self):
        if not self.crystal_file.exists():
            raise FileNotFoundError(f"Crystal file {self.crystal_file} does not exist")

        self._construct_unit_cell()
        self._generate_slabs()
        self.save_slabs(Path("output"))

    def _construct_unit_cell(self):
        self.unit_cell = Structure.from_file(self.crystal_file, primitive=False)
        self.unit_cell.add_oxidation_state_by_element({"Ca": 2, "C": 4, "O": -2})
        self.space_group = SpacegroupAnalyzer(self.unit_cell)
        if self.verbose:
            print(
                "Unit cell space group:"
                + f"{self.space_group.get_space_group_symbol()}"
            )
            print(f"Hexagonal lattice: {self.unit_cell.lattice.is_hexagonal()}")

        self.unit_cell = self.space_group.get_conventional_standard_structure()
        if self.verbose:
            info = str(self.unit_cell).split("\n")[:5]
            for line in info:
                print(line)

    def _generate_slabs(self):
        self.generator = SlabGenerator(
            # initial structure
            self.unit_cell,
            # miller index
            miller_index=self.miller_indices,
            # Minimum size in angstroms of layers containing atoms
            min_slab_size=self.slab_thickness,
            # Minimum size in angstroms of layers containing vacuum
            min_vacuum_size=10,
            # LLL reduction of lattice
            lll_reduce=False,
            # center the slab in the cell with equal vacuum
            # spacing from the top and bottom
            center_slab=True,
            # set min_slab_size and min_vac_size in units of
            # hkl planes (True) or Angstrom (False/default)
            in_unit_planes=False,
            # reduce any generated slabs to a primitive cell
            primitive=True,
            # reorients the lattice parameters such that the
            # c direction is along the z axis
            reorient_lattice=True,
        )
        self.slabs = self.generator.get_slabs()

        if self.verbose:
            print(f"Generated {len(self.slabs)} slabs")
            for i, slab in enumerate(self.slabs):
                print(
                    f"Slab {i}\n\tPolar: {slab.is_polar()}"
                    + f"\n\tSymmetric: {slab.is_symmetric()}"
                )

    def save_slabs(self, output_dir: Path):
        if not output_dir.exists():
            output_dir.mkdir(parents=True)

        # create unit cell and slabs
        if self.slabs is None:
            self._construct_unit_cell()
            self._generate_slabs()

        # create basic cif file
        fname_base = (
            f"{self.filename}-"
            + "".join([str(s) for s in self.miller_indices])
            + "_surface"
        )
        fname_base = output_dir / fname_base
        for i, slab in enumerate(self.slabs):
            supercell = slab * self.replicates
            supercell_dims = supercell.lattice.matrix.diagonal() / 10.0
            supercell_dims = "_".join([f"{dim:.2f}" for dim in supercell_dims])
            fname = (
                f"{fname_base}-{supercell_dims}_nm_size"
                + f"-{slab.is_polar()}_polar-{slab.is_symmetric()}_symmetric-{i}_slab"
            )
            supercell.to(filename=f"{fname}.cif")
            self.create_pdb(fname)

    def create_pdb(self, filename: Path) -> None:
        self.cif_to_pdb(filename)
        self.pdb_clean(filename)
        os.remove(f"{filename}.cif")

    def cif_to_pdb(self, filename: Path) -> None:
        # use OpenBabel to read cif file and add bonds
        mol = ob.OBMol()
        ob_conv = ob.OBConversion()
        ob_conv.SetInAndOutFormats("cif", "pdb")
        ob_conv.ReadFile(mol, f"{filename}.cif")

        # iterate through atoms and if atom is Ca, remove bonds to other atoms
        mol.ConnectTheDots()
        bonds = []
        for atom in ob.OBMolAtomIter(mol):
            if atom.GetType() == "Ca":
                for bond in ob.OBAtomBondIter(atom):
                    bonds.append(bond)
        for bond in bonds:
            mol.DeleteBond(bond)

        # output file
        ob_conv.WriteFile(mol, f"{filename}.pdb")

        if self.verbose:
            print(f"OpenBabel converted {filename}.cif to {filename}.pdb")
            print(f"\tNumber of atoms: {mol.NumAtoms()}")
            print(f"\tNumber of bonds: {mol.NumBonds()}")
            print(f"\tNumber of residues: {mol.NumResidues()}")

    def pdb_clean(self, filename: Path) -> None:
        # use MDAnalysis to read pdb file and guess bonds
        u = mda.Universe(
            f"{filename}.pdb",
            guess_bonds=True,
            vdwradii={"Ca": 0.0, "C": 0.7, "O": 0.6},
            topology_format="PDB",
        )
        ag = u.atoms

        # set record type and segment id
        for atom in ag:  # pylint: disable=not-an-iterable
            atom.record_type = "ATOM"
            atom.segment.segid = ""

        # set atom and residue names
        for atom in ag:  # pylint: disable=not-an-iterable
            if atom.name == "C":
                atom.name = "CX1"
                atom.residue.resname = "CRB"
            elif atom.name == "O":
                atom.name = "OX1"
                atom.residue.resname = "CRB"
            elif atom.name == "CA":
                atom.residue.resname = "CA"
            else:
                raise ValueError(f"Unknown atom name {atom.name}")

        try:
            # add bonds to oxygen atoms
            for atom in ag:  # pylint: disable=not-an-iterable
                if (atom.name == "OX1") and len(atom.bonds) == 0:
                    sel_c = u.select_atoms(
                        f"element C and around 1.3 index {atom.index}"
                    )
                    if len(sel_c) == 1:
                        u.add_bonds([(atom.index, sel_c[0].index)])
                    else:
                        raise ValueError(
                            f"{len(sel_c)} carbons found around atom {atom.index}"
                        )

            # update atom names for oxygen atoms
            for atom in ag:  # pylint: disable=not-an-iterable
                if atom.name != "CX1":
                    continue

                group = atom.bonded_atoms + atom
                if len(group) != 4:
                    raise ValueError(
                        f"Group size for atom {atom.index} is {len(group)}"
                    )

                for j, gr_atom in enumerate(group):
                    gr_atom.name = f"OX{j+1}"

            # add residue id
            idx_resid_c = 1
            idx_resid_ca = len(u.select_atoms("resname CA")) + 1
            for atom in ag:  # pylint: disable=not-an-iterable
                if (atom.name in ["OX1", "OX2", "OX3"]) and (len(atom.bonds) != 1):
                    raise ValueError(
                        f"Oxygen atom {atom.index} has {len(atom.bonds)} bonds"
                    )

                if atom.name == "CX1":
                    if len(atom.bonds) != 3:
                        raise ValueError(
                            f"Carbon atom {atom.index} has {len(atom.bonds)} bonds"
                        )
                    res = u.add_Residue(
                        resname="CRB",
                        resid=idx_resid_c,
                        resnum=idx_resid_c,
                        segid="",
                        chainID="",
                        icode="",
                    )
                    atom.residue = res
                    idx_resid_c += 1

                if atom.name == "CA":
                    if len(atom.bonds) != 0:
                        raise ValueError(
                            f"Calcium atom {atom.index} has {len(atom.bonds)} bonds"
                        )
                    res = u.add_Residue(
                        resname="CA",
                        resid=idx_resid_ca,
                        resnum=idx_resid_ca,
                        segid="",
                        chainID="",
                        icode="",
                    )
                    atom.residue = res
                    idx_resid_ca += 1

            # set oxygen residue id by connected carbon
            for atom in ag:  # pylint: disable=not-an-iterable
                if atom.name in ["OX1", "OX2", "OX3"]:
                    if len(atom.bonds) != 1:
                        raise ValueError(
                            f"Oxygen atom {atom.index} has {len(atom.bonds)} bonds"
                        )
                    atom.residue = atom.bonded_atoms[0].residue

            # check that no atoms have the same coordinates
            coords = u.atoms.positions
            if len(coords) != len(np.unique(coords, axis=0)):
                raise ValueError("Atoms have the same coordinates")

            # unwrap all atoms
            transform = [
                transformations.unwrap(u.atoms),
                transformations.center_in_box(u.atoms),
                transformations.wrap(u.atoms, compound="residues"),
            ]
            u.trajectory.add_transformations(*transform)

        except Exception as e:
            os.remove(f"{filename}.pdb")
            parent_dir = Path(filename).parent
            filename = parent_dir / f"error_{Path(filename).name}"
            u.atoms.write(f"{filename}.pdb", bonds="conect", reindex=False)
            warnings.warn(f"Error in pdb_clean: {e}")
            return

        # write the new structure
        u.atoms.write(
            f"{filename}.pdb",
            remarks="CaCO3 crystal structure generated with Pymatgen, "
            + "OpenBabel and MDAnalysis",
            bonds="conect",
            reindex=False,
        )

        # load new structure
        with open(f"{filename}.pdb", "r", encoding="utf-8") as f:
            lines = f.readlines()

        # find first and last atom line indices
        atom_lines = []
        for i, line in enumerate(lines):
            if line.startswith("ATOM"):
                atom_lines.append(i)
        first_atom_line = atom_lines[0]
        last_atom_line = atom_lines[-1]

        # reorder indices in atom lines by residue number (column 23-26)
        resids = []
        for i in range(first_atom_line, last_atom_line + 1):
            resid = int(lines[i][22:26])
            resids.append(resid)
        # sort atom lines by residue number
        atom_lines = np.array(atom_lines)
        atom_lines = atom_lines[np.argsort(resids)]

        # write reordered pdb file
        with open(f"{filename}.pdb", "w", encoding="utf-8") as f:
            for i in range(first_atom_line):
                f.write(lines[i])
            for i in atom_lines:
                f.write(lines[i])
            for i in range(last_atom_line + 1, len(lines)):
                f.write(lines[i])

        # update indices in pdb file
        u = mda.Universe(f"{filename}.pdb")
        u.atoms.write(
            f"{filename}.pdb",
            remarks="CaCO3 crystal structure generated with Pymatgen, "
            + "OpenBabel and MDAnalysis",
            bonds="conect",
            reindex=True,
        )
