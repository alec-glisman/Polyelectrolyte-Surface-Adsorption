from dataclasses import dataclass, field
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
from scipy.spatial.transform import Rotation


@dataclass(frozen=True)
class SurfaceProperties:
    miller_indices: np.array = field(default_factory=lambda: np.array([0, 0, 0]))
    surface_dim: np.array = field(default_factory=lambda: np.array([0.0, 0.0]))  # [nm]
    n_layers: int = 0
    z_flip: bool = False
    z_translation: float = 0.0  # [nm]


def clean_pdb(input_file: Path, output_file: Path) -> None:
    # load universe
    u = mda.Universe(f"{input_file}")
    ag = u.atoms

    # rigid body transformations to remove empty space
    z_min = np.nanmin(u.atoms.positions[:, 2])
    z_max = np.nanmax(u.atoms.positions[:, 2])
    trans = [0, 0, -z_min]
    dim = u.dimensions
    dim[2] = z_max - z_min
    transform = [
        transformations.translate(trans),
        transformations.boxdimensions.set_dimensions(dim),
    ]
    u.trajectory.add_transformations(*transform)

    # set record type and segment id
    for atom in ag:  # pylint: disable=not-an-iterable
        atom.record_type = "ATOM"
        atom.segment.segid = ""

    # set atom and residue names
    for atom in ag:  # pylint: disable=not-an-iterable
        if atom.name.startswith("Ca"):
            atom.name = "CA"
            atom.residue.resname = "CA"
            if len(atom.bonded_atoms) != 0:
                msg = f"Calcium atom {atom.index} has {len(atom.bonded_atoms)} bonds"
                raise ValueError(msg)

        elif atom.name.startswith("C"):
            atom.name = "CX1"
            atom.residue.resname = "CRB"
            if len(atom.bonded_atoms) != 3:
                msg = f"Carbon atom {atom.index} has {len(atom.bonded_atoms)} bonds"
                raise ValueError(msg)

            # set oxygen atom names
            for j, gr_atom in enumerate(atom.bonded_atoms):
                if len(gr_atom.bonded_atoms) != 1:
                    msg = (
                        f"Oxygen atom {gr_atom.index} has {len(gr_atom.bonded_atoms)}"
                        + " bonds"
                    )
                    raise ValueError(msg)
                gr_atom.name = f"OX{j+1}"
                gr_atom.residue.resname = "CRB"

    # add residue id

    idx_resid = 1
    for atom in u.select_atoms("name CX1"):
        res = u.add_Residue(
            resname="CRB",
            resid=idx_resid,
            resnum=idx_resid,
            segid="",
            chainID="",
            icode="",
        )
        atom.residue = res
        idx_resid += 1

        for bonded_atom in atom.bonded_atoms:
            bonded_atom.residue = atom.residue

    for atom in u.select_atoms("name CA"):
        res = u.add_Residue(
            resname="CA",
            resid=idx_resid,
            resnum=idx_resid,
            segid="",
            chainID="",
            icode="",
        )
        atom.residue = res
        idx_resid += 1

    # write the new structure
    u.atoms.write(
        f"{output_file}",
        remarks="CaCO3 crystal structure generated with MDAnalysis",
        bonds="conect",
        reindex=False,
    )

    # load new structure
    with open(f"{output_file}", "r", encoding="utf-8") as f:
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
    with open(f"{output_file}", "w", encoding="utf-8") as f:
        for i in range(first_atom_line):
            f.write(lines[i])
        for i in atom_lines:
            f.write(lines[i])
        for i in range(last_atom_line + 1, len(lines)):
            f.write(lines[i])

    # update indices and unwrap atoms in pdb file
    u = mda.Universe(f"{output_file}")
    transform = [
        transformations.unwrap(u.atoms),
    ]
    u.trajectory.add_transformations(*transform)
    u.atoms.write(
        f"{output_file}",
        remarks="CaCO3 crystal structure generated with MDAnalysis",
        bonds="conect",
        reindex=True,
    )


def replicates(filename: Path, size_nm: int) -> tuple:
    uni = mda.Universe(f"{filename}")
    dim = uni.dimensions
    rep = np.ones(3, dtype=int)
    for i in range(2):
        rep[i] = max(np.round(size_nm * 10 / dim[i]), 1)
    return rep


def replicate_pdb(filename: Path, replicate: tuple) -> None:
    uni = mda.Universe(f"{filename}")
    box = uni.dimensions[:3]
    angles = uni.dimensions[3:]
    copied = []

    for x in range(replicate[0]):
        for y in range(replicate[1]):
            for z in range(replicate[2]):
                u_ = uni.copy()
                move_by = box * (x, y, z)
                u_.atoms.translate(move_by)
                copied.append(u_.atoms)

    new_universe = mda.Merge(*copied)
    new_box = box * (replicate[0], replicate[1], replicate[2])
    new_universe.dimensions = list(new_box) + list(angles)
    # write the new structure
    new_universe.atoms.write(
        f"{filename}",
        remarks="CaCO3 crystal structure generated with MDAnalysis",
        bonds="conect",
        reindex=True,
    )


class SurfaceGen:

    def __init__(
        self,
        crystal_file: Path,
        miller_indices: np.array,
        slab_thickness: float,
        replicates: np.array,
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
            # Minimum size in angstroms or layers containing atoms
            min_slab_size=self.slab_thickness,
            # Minimum size in angstroms or layers containing vacuum
            min_vacuum_size=1,
            # Whether or not slabs will be orthogonalized
            lll_reduce=True,
            # center the slab in the cell with equal vacuum
            # spacing from the top and bottom
            center_slab=True,
            # set min_slab_size and min_vac_size in units of
            # hkl planes (True) or Angstrom (False/default)
            in_unit_planes=True,
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
                f"{fname_base}"
                + f"-{supercell_dims}_nm_size"
                + f"-polar-{slab.is_polar()}"
                + f"-symmetric-{slab.is_symmetric()}"
                + f"-slab-{i}"
            )
            supercell.to(filename=f"{fname}.cif")
            self.create_pdb(fname)

    def create_pdb(self, filename: Path) -> None:
        self.cif_to_pdb(filename)
        self.pdb_clean(filename)
        os.remove(f"{filename}.cif")

    def cif_to_pdb(self, filename: Path) -> None:
        # use OpenBabel to read cif file and write pdb file
        mol = ob.OBMol()
        ob_conv = ob.OBConversion()
        ob_conv.SetInAndOutFormats("cif", "pdb")
        ob_conv.ReadFile(mol, f"{filename}.cif")
        ob_conv.WriteFile(mol, f"{filename}.pdb")
        if self.verbose:
            print(f"OpenBabel converted {filename}.cif to {filename}.pdb")
            print(f"\tNumber of atoms: {mol.NumAtoms()}")
            print(f"\tNumber of bonds: {mol.NumBonds()}")
            print(f"\tNumber of residues: {mol.NumResidues()}")

        # remove all lines containing "CONECT" in the pdb file
        with open(f"{filename}.pdb", "r", encoding="utf-8") as f:
            lines = f.readlines()

        with open(f"{filename}.pdb", "w", encoding="utf-8") as f:
            for line in lines:
                if "CONECT" not in line:
                    f.write(line)

    def pdb_clean(self, filename: Path) -> None:

        # rigid body transformations to remove empty space
        u = mda.Universe(f"{filename}.pdb", guess_bonds=False)
        ag = u.atoms
        z_min = np.nanmin(u.atoms.positions[:, 2])
        z_max = np.nanmax(u.atoms.positions[:, 2])
        trans = [0, 0, -z_min]
        dim = u.dimensions
        dim[2] = z_max - z_min
        transform = [
            transformations.translate(trans),
            transformations.boxdimensions.set_dimensions(dim),
        ]
        u.trajectory.add_transformations(*transform)

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
            oxygens = u.select_atoms("name OX1 and resname CRB")
            carbons = u.select_atoms("name CX1 and resname CRB")

            # add bonds between oxygen and nearest carbon atoms
            for atom in oxygens:  # pylint: disable=not-an-iterable
                nearest_carbon = u.select_atoms(
                    f"(name CX1 and resname CRB) and around 1.3 index {atom.index}",
                    periodic=True,
                )
                if len(nearest_carbon) == 1:
                    u.add_bonds([(atom.index, nearest_carbon[0].index)])

            # assuming there is at least one fully connected carbonate group, find the
            # plane of the carbonate group
            surf_norm = None
            for carbon in carbons:
                if len(carbon.bonded_atoms) == 3:
                    c_o1 = carbon.bonded_atoms[0].position - carbon.position
                    c_o2 = carbon.bonded_atoms[1].position - carbon.position

                    c_o1 = np.array(
                        [
                            c_o1[i] - np.round(c_o1[i] / dim[i]) * dim[i]
                            for i in range(3)
                        ]
                    )
                    c_o2 = np.array(
                        [
                            c_o2[i] - np.round(c_o2[i] / dim[i]) * dim[i]
                            for i in range(3)
                        ]
                    )

                    # surface normal of the carbonate group
                    surf_norm = np.cross(c_o1, c_o2)
                    surf_norm = surf_norm / np.linalg.norm(surf_norm)
                    break

            if surf_norm is None:
                raise ValueError("Could not find a fully connected carbonate group")

            # reconstruct bonds for oxygen atoms with no bonds
            for oxygen in oxygens:
                if len(oxygen.bonded_atoms) != 0:
                    continue

                for carbon in carbons:
                    # carbonate is constructed
                    if len(carbon.bonded_atoms) == 3:
                        continue

                    # add last bond to carbon atom
                    elif len(carbon.bonded_atoms) == 2:
                        # plane of carbonate group
                        c_o1 = carbon.bonded_atoms[0].position - carbon.position
                        c_o2 = carbon.bonded_atoms[1].position - carbon.position
                        c_o1 = np.array(
                            [
                                c_o1[i] - np.round(c_o1[i] / dim[i]) * dim[i]
                                for i in range(3)
                            ]
                        )
                        c_o2 = np.array(
                            [
                                c_o2[i] - np.round(c_o2[i] / dim[i]) * dim[i]
                                for i in range(3)
                            ]
                        )

                        # vector for c-03 is negative of the sum of c-o1 and c-o2
                        c_o3 = -c_o1 - c_o2
                        c_o3 = c_o3 / np.linalg.norm(c_o3)

                        # position of oxygen atom
                        oxygen.position = carbon.position + c_o3 * 1.285
                        u.add_bonds([(oxygen.index, carbon.index)])
                        break  # only add one bond per oxygen atom

                    # add second bond to carbon atom
                    elif len(carbon.bonded_atoms) == 1:
                        c_o1 = carbon.bonded_atoms[0].position - carbon.position
                        c_o1 = np.array(
                            [
                                c_o1[i] - np.round(c_o1[i] / dim[i]) * dim[i]
                                for i in range(3)
                            ]
                        )
                        c_o1 = c_o1 / np.linalg.norm(c_o1)

                        # rotate c_o1 by 120 degrees along surf_norm
                        c_o2 = Rotation.from_rotvec(
                            119.486687 * surf_norm, degrees=True
                        ).apply(c_o1)

                        oxygen.position = carbon.position + c_o2 * 1.285
                        u.add_bonds([(oxygen.index, carbon.index)])
                        break  # only add one bond per oxygen atom

                    elif len(carbon.bonded_atoms) == 0:
                        raise ValueError(
                            f"Carbon atom {carbon.index} has {len(carbon.bonded_atoms)}"
                            + " bonds"
                        )

            # update atom names for oxygen atoms
            for atom in carbons:  # pylint: disable=not-an-iterable
                if len(atom.bonded_atoms) != 3:
                    raise ValueError(
                        f"Carbon atom {atom.index} has {len(atom.bonded_atoms)} bonds"
                    )

                for j, gr_atom in enumerate(atom.bonded_atoms):
                    gr_atom.name = f"OX{j+1}"

            # add residue id
            idx_resid_c = 1
            idx_resid_ca = len(u.select_atoms("resname CA")) + 1
            for atom in ag:  # pylint: disable=not-an-iterable
                if atom.name == "CX1":
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

                    # add residue id for attached oxygen atoms
                    for bonded_atom in atom.bonded_atoms:
                        bonded_atom.residue = atom.residue

                if atom.name == "CA":
                    if len(atom.bonded_atoms) != 0:
                        raise ValueError(
                            f"Calcium atom {atom.index} has {len(atom.bonded_atoms)}"
                            + " bonds"
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

            # check that no atoms have the same coordinates
            coords = u.atoms.positions
            if len(coords) != len(np.unique(coords, axis=0)):
                raise ValueError("Atoms have the same coordinates")

        except Exception as e:
            os.remove(f"{filename}.pdb")
            parent_dir = Path(filename).parent
            filename = parent_dir / f"error_{Path(filename).name}"
            u.atoms.write(f"{filename}.pdb", bonds="conect", reindex=False)
            warnings.warn(f"Error in pdb_clean: \n\t{e}")
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
        # unwrap all atoms
        transform = [
            transformations.unwrap(u.atoms),
            # transformations.center_in_box(u.atoms),
            # transformations.wrap(u.atoms, compound="residues"),
        ]
        u.trajectory.add_transformations(*transform)
        u.atoms.write(
            f"{filename}.pdb",
            remarks="CaCO3 crystal structure generated with Pymatgen, "
            + "OpenBabel and MDAnalysis",
            bonds="conect",
            reindex=True,
        )
