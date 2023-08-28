"""This file contains classes and functions to add in the creation of
polymer coordinate/structure files from simple input strings.

Note that `rdkit` is required to use this module. This package can be
installed using `conda` with the following command:
.. code-block:: bash
    $ conda install -c conda-forge rdkit


The main class is `TextPolymer` which takes a list of monomers and their
stereochemistries and returns the smiles and pdb representations of the
polymer.

The polymer_generator.py script uses this module to create the polymer
smiles and pdb files for the charge fitting via RESP and LJ/bonded
parameters via Antechamber/Acpype.

Author: Alec Glisman (GitHub: @alec-glisman)
Date: April 20th, 2023

Example
-------
    .. code-block:: python
    # imports
    from polymer_generator import TextPolymer

    # polymers for charge fitting
    N_MONOMER = 3
    polymers = [
        ["alcohol"] * N_MONOMER,
        ["acetate"] * N_MONOMER,
        ["acrylate"] * N_MONOMER,
        ["acrylate_ion"] * N_MONOMER,
    ]

    # filenames for data output
    fnames = [
        f"pva-{N_MONOMER}mer-atactic-Hend-chain-em",
        f"pvac-{N_MONOMER}mer-atactic-Hend-chain-em",
        f"paai-{N_MONOMER}mer-atactic-Hend-chain-em",
        f"paan-{N_MONOMER}mer-atactic-Hend-chain-em",
    ]

    # stereochemistries for charge fitting
    if N_MONOMER == 3:
        stereochemistry = ["d", "l", "l"]
    elif N_MONOMER == 6:
        stereochemistry = ["d", "l", "l", "d", "d", "l"]
    else:
        raise ValueError("The number of monomers is not supported yet.")

    # generate smiles
    for i in range(len(polymers)):
        tp = TextPolymer(polymers[i], stereochemistry)
        tp.smiles(save_file="smiles.txt")
        tp.pdb(save_file=f"{fnames[i]}.pdb")
"""

# imports
from rdkit import Chem
from rdkit.Chem import AllChem


class TextPolymer:
    """Create a polymer from a list of monomers and stereochemistries.

    Methods
    -------
    smiles(save_file: str = None) -> str
        Return the SMILES representation of the polymer.
    pdb(save_file: str = None) -> str
        Return the PDB representation of the polymer.

    Attributes
    ----------
    _monomer : list[str]
        List of monomer names.
    _stereochemistry : list[str]
        List of stereochemistry names.
    _length: int
        Number of monomers in the polymer chain.
    _n_terminus : str
        Name of the n-terminus end-cap.
    _c_terminus : str
        Name of the c-terminus end-cap.
    _smiles : str
        SMILES representation of the polymer.
    _pdb : str
        PDB representation of the polymer.
    _pname : str
        Name of the polymer.
    monomer_dict : dict[str, dict[str, str]]
        Dictionary of monomer names that are supported and their SMILES repr
        (class attribute).
    cap_dict : dict[str, dict[str, str]]
        Dictionary of end-cap names that are supported and their SMILES repr
        (class attribute).
    stereochemistry_dict : dict[str, str]
        Dictionary of stereochemistry names that are supported and their SMILES repr
        (class attribute).

    Examples
    --------
    >>> fname = "mixed-3mer-atactic-Hend-chain-em"
    >>> tp = TextPolymer(["alcohol", "acetate", "acrylate"], ["d", "l", "l"])
    >>> smiles = tp.smiles(save_file=f"{fname}.smiles")
    >>> print(smiles)
    C[C@H](O)C[C@@H](OC(=O)C)C[C@@H](C(=O)O)
    >>> pdb = tp.pdb(save_file=f"{fname}.pdb")
    """

    # dictionary of monomer names that are supported and their SMILES repr
    monomer_dict = {
        "alcohol": {
            "smiles": "C[C@H](O)",
            "heavy_atom_labels": ["C", "CA", "OA"],
            "hydrogen_atom_labels": ["HC1", "HC2", "HA1", "HOA"],
            "n_terminus_hydrogen_atoms": ["HC1", "HC2", "HC3", "HA1", "HOA"],
            "c_terminus_hydrogen_atoms": ["HC1", "HC2", "HA1", "HA2", "HOA"],
            "resname_center": "ALC",
            "resname_n_terminus": "LAL",
            "resname_c_terminus": "RAL",
            "cap_n_terminus": "hydrogen",
            "cap_c_terminus": "hydrogen",
        },
        "acetate": {
            "smiles": "C[C@H](OC(=O)C)",
            "heavy_atom_labels": ["C", "CA", "OA", "CB", "OB", "CG"],
            "hydrogen_atom_labels": ["HC1", "HC2", "HA1", "HG1", "HG2", "HG3"],
            "n_terminus_hydrogen_atoms": [
                "HC1",
                "HC2",
                "HC3",
                "HA1",
                "HG1",
                "HG2",
                "HG3",
            ],
            "c_terminus_hydrogen_atoms": [
                "HC1",
                "HC2",
                "HA1",
                "HA2",
                "HG1",
                "HG2",
                "HG3",
            ],
            "resname_center": "ACE",
            "resname_n_terminus": "LAC",
            "resname_c_terminus": "RAC",
            "cap_n_terminus": "hydrogen",
            "cap_c_terminus": "hydrogen",
        },
        "acrylate": {
            "smiles": "C[C@H](C(=O)O)",
            "heavy_atom_labels": ["C", "CA", "CB", "OB1", "OB2"],
            "hydrogen_atom_labels": ["HC1", "HC2", "HA1", "HB2"],
            "n_terminus_hydrogen_atoms": ["HC1", "HC2", "HC3", "HA1", "HB2"],
            "c_terminus_hydrogen_atoms": ["HC1", "HC2", "HA1", "HA2", "HB2"],
            "resname_center": "ACN",
            "resname_n_terminus": "LAN",
            "resname_c_terminus": "RAN",
            "cap_n_terminus": "hydrogen",
            "cap_c_terminus": "hydrogen",
        },
        "acrylate_ion": {
            "smiles": "C[C@H](C(=O)[O-])",
            "heavy_atom_labels": ["C", "CA", "CB", "OB1", "OB2"],
            "hydrogen_atom_labels": ["HC1", "HC2", "HA1"],
            "n_terminus_hydrogen_atoms": ["HC1", "HC2", "HC3", "HA1"],
            "c_terminus_hydrogen_atoms": ["HC1", "HC2", "HA1", "HA2"],
            "resname_center": "ACI",
            "resname_n_terminus": "LAI",
            "resname_c_terminus": "RAI",
            "cap_n_terminus": "hydrogen",
            "cap_c_terminus": "hydrogen",
        },
    }
    # dictionary of end-cap names that are supported and their SMILES repr
    cap_dict = {
        "hydrogen": {
            "smiles": "",
            "n_heavy_atoms": 0,
            "n_hydrogen_atoms": 1,
        }
    }
    # dictionary of stereochemistry names that are supported and their SMILES repr
    stereochemistry_dict = {
        "d": "@",
        "l": "@@",
    }

    def __init__(
        self,
        monomer: list[str],
        stereochemistry: list[str],
        n_terminus: str = "hydrogen",
        c_terminus: str = "hydrogen",
    ) -> None:
        """Create a polymer creation object.

        Parameters
        ----------
        monomer : list[str]
            List of monomer names.
        stereochemistry : list[str]
            List of stereochemistry names.
        n_terminus : str, optional
            Name of the n-terminus end-cap, by default "hydrogen"
        c_terminus : str, optional
            Name of the c-terminus end-cap, by default "hydrogen"

        Raises
        ------
        ValueError
            If the length of monomers and stereochemistries are not the same.
        TypeError
            If monomer is not a list of strings.
        TypeError
            If stereochemistry is not a list of strings.
        TypeError
            If n_terminus is not a string.
        TypeError
            If c_terminus is not a string.
        ValueError
            If monomer list is empty.
        ValueError
            If stereochemistry list is empty.
        ValueError
            If at least one monomer is not supported.
        ValueError
            If at least one stereochemistry is not supported.
        ValueError
            If n_terminus is not supported.
        ValueError
            If c_terminus is not supported.
        """
        # check if monomer and stereochemistry are the same length
        if len(monomer) != len(stereochemistry):
            raise ValueError(
                "The length of monomers and stereochemistries should be the same."
            )
        # check if monomer is a list
        if not isinstance(monomer, list):
            raise TypeError("Monomer should be a list of strings.")
        # check if stereochemistry is a list
        if not isinstance(stereochemistry, list):
            raise TypeError("Stereochemistry should be a list of strings.")
        # check if n_terminus is a string
        if not isinstance(n_terminus, str):
            raise TypeError("N-terminus should be a string.")
        # check if c_terminus is a string
        if not isinstance(c_terminus, str):
            raise TypeError("C-terminus should be a string.")
        # check if monomer list is not empty
        if len(monomer) == 0:
            raise ValueError("Monomer list should not be empty.")
        # check if stereochemistry list is not empty
        if len(stereochemistry) == 0:
            raise ValueError("Stereochemistry list should not be empty.")
        # check if all monomers are supported
        if not all([m in self.monomer_dict for m in monomer]):
            raise ValueError("At least one monomer is not supported.")
        # check if all stereochemistries are supported
        if not all([s in self.stereochemistry_dict for s in stereochemistry]):
            raise ValueError("At least one stereochemistry is not supported.")
        # check if n_terminus is supported
        if n_terminus not in self.cap_dict:
            raise ValueError("N-terminus is not supported.")
        # check if c_terminus is supported
        if c_terminus not in self.cap_dict:
            raise ValueError("C-terminus is not supported.")

        # set instance variables
        self._monomer: list[str] = monomer
        self._stereochemistry: list[str] = stereochemistry
        self._length: int = len(monomer)
        self._n_terminus: str = n_terminus
        self._c_terminus: str = c_terminus
        self._smiles: str = None
        self._pdb: str = None

        # polymer ID
        m_str = "_".join(monomer)
        s_str = "_".join(stereochemistry)
        self._pname: str = f"{m_str}-{s_str}-nt_{n_terminus}-ct_{c_terminus}"

    def smiles(self, save_file: str = None) -> str:
        """Create a SMILES representation of the polymer input string.

        Parameters
        ----------
        save_file : str, optional
            Path to a file to save the SMILES string, by default None

        Returns
        -------
        str
            SMILES representation of the polymer.
        """
        # left cap
        smiles = self.cap_dict[self._n_terminus]["smiles"]

        # middle monomers
        for i, (monomer, stereo) in enumerate(
            zip(self._monomer, self._stereochemistry)
        ):
            # get monomer string
            mon = self.monomer_dict[monomer]["smiles"]
            # replace all @ in monomer with @ or @@ according to stereochemistry
            mon = mon.replace("@", self.stereochemistry_dict[stereo])

            # replace last [C@H] with [C@H2] if c_terminus is hydrogen
            if i == self._length - 1 and self._c_terminus == "hydrogen":
                mon = mon.replace(r"@H", r"@H2")

            # append to smiles
            smiles += mon

        # right cap
        smiles += self.cap_dict[self._c_terminus]["smiles"]

        self._smiles = smiles

        # save smiles to file
        if save_file is not None:
            with open(save_file, "a", encoding="utf-8") as file:
                file.write(f"{self._pname}\n")
                file.write(f"{self._smiles}\n")
                file.write("\n")

        return smiles

    def pdb(self, save_file: str = None) -> str:
        """Create a PDB representation of the polymer input string.

        Parameters
        ----------
        save_file : str, optional
            Path to a file to save the PDB string, by default None

        Returns
        -------
        str
            PDB representation of the polymer.

        Raises
        ------
        ValueError
            If geometry optimization failed.
        ValueError
            If geometry optimization did not converge.
        """
        # create smiles string
        if self._smiles is None:
            self.smiles()

        # convert smiles to pdb file and add coordinates
        mol = Chem.MolFromSmiles(self._smiles)
        mol = Chem.AddHs(mol, addCoords=True)
        # docs: https://rdkit.org/docs/source/rdkit.Chem.rdDistGeom.html
        embed = AllChem.EmbedMolecule(
            mol,
            maxAttempts=500000,
            enforceChirality=True,
            useRandomCoords=True,
            useBasicKnowledge=False,
        )
        if embed == -1:
            raise ValueError("Molecule embedding failed.")

        # geometry optimization of coordinates
        try:
            converge = Chem.rdForceFieldHelpers.MMFFOptimizeMolecule(
                mol, maxIters=100000
            )
            if converge == -1:
                raise ValueError("Geometry optimization failed.")
            if converge == 1:
                raise ValueError("Geometry optimization did not converge.")
        except ValueError as exc:
            print("Error: geometry optimization failed.")
            print(f"Monomer: {self._monomer}")
            print(f"Stereochemistry: {self._stereochemistry}")
            print(f"{exc}")
            pass

        # convert optimized coordinates to pdb format
        pdb_str = Chem.rdmolfiles.MolToPDBBlock(mol)

        # replace HETATM with ATOM and UNL with UNL A
        pdb_str = pdb_str.replace("HETATM", "ATOM  ")
        pdb_str = pdb_str.replace("UNL  ", "UNL A")
        # add heavy atom resname and resid
        pdb_str = self._pdb_heavy_atoms(pdb_str)
        # add hydrogen atom resname and resid
        pdb_str = self._pdb_hydrogen_atoms(pdb_str)
        # reorder lines so that hydrogen atoms are with their heavy atom
        pdb_str = self._pdb_order_atoms(pdb_str)
        self._pdb = pdb_str

        # save pdb to file
        if save_file is not None:
            with open(save_file, "w", encoding="utf-8") as file:
                # add header
                file.write(f"COMPND    {self._pname}\n")
                file.write("AUTHOR    GENERATED BY ALEC GLISMAN WITH RDKIT\n")
                # output pdb text
                file.write(pdb_str)

    def _pdb_heavy_atoms(self, pdb_str: str) -> str:
        # split pdb file into list of lines
        pdb_list = pdb_str.splitlines()

        # iterate through monomers in chain
        idx_line = 0
        for i, mon in enumerate(self._monomer):
            # get resname
            if i == 0:
                name = self.monomer_dict[mon]["resname_n_terminus"]
            elif i == self._length - 1:
                name = self.monomer_dict[mon]["resname_c_terminus"]
            else:
                name = self.monomer_dict[mon]["resname_center"]

            # iterate through heavy atoms in monomer
            for atom in self.monomer_dict[mon]["heavy_atom_labels"]:
                pdb_list[idx_line] = self._pdb_line_replace(
                    pdb_list[idx_line], atom, name, i + 1
                )
                idx_line += 1

        # return the pdb file as a string
        return "\n".join(pdb_list)

    def _pdb_hydrogen_atoms(self, pdb_str: str) -> str:
        # split pdb file into list of lines
        pdb_list = pdb_str.splitlines()

        # iterate through pdb file and add resname/resid of hydrogen atoms
        idx_line = -1
        for idx, line in enumerate(pdb_list):
            # skip non-atom and non-hydrogen lines
            if not line.startswith("ATOM") or line[13] != "H":
                continue
            # find first hydrogen atom in pdb_list
            if line[13] == "H":
                idx_line = idx
                break

        if idx_line == -1 or idx_line == len(pdb_list):
            raise ValueError("No hydrogen atoms found in pdb file.")

        # iterate through monomers in chain
        for i, mon in enumerate(self._monomer):
            # get resname
            if i == 0:
                name = self.monomer_dict[mon]["resname_n_terminus"]
                atoms = self.monomer_dict[mon]["n_terminus_hydrogen_atoms"]
            elif i == self._length - 1:
                name = self.monomer_dict[mon]["resname_c_terminus"]
                atoms = self.monomer_dict[mon]["c_terminus_hydrogen_atoms"]
            else:
                name = self.monomer_dict[mon]["resname_center"]
                atoms = self.monomer_dict[mon]["hydrogen_atom_labels"]

            # iterate through heavy atoms in monomer
            for atom in atoms:
                if pdb_list[idx_line][13] != "H":
                    raise ValueError(
                        "No hydrogen atoms found in line."
                        + f"\n{pdb_list[idx_line]}\nAtom: {atom}"
                        + "\nCurrent PDB file:\n"
                        + "\n".join(pdb_list)
                    )

                try:
                    pdb_list[idx_line] = self._pdb_line_replace(
                        pdb_list[idx_line], atom, name, i + 1
                    )
                except IndexError as exc:
                    print("Error: hydrogen atom resname/resid not added to pdb file.")
                    print(f"Monomer: {mon}")
                    print("\n".join(pdb_list))
                    raise exc
                idx_line += 1

        # return the pdb file as a string
        return "\n".join(pdb_list)

    def _pdb_order_atoms(self, pdb_str: str) -> str:
        # split pdb file into list of lines
        pdb_list = pdb_str.splitlines()

        # split off ATOM and CONECT lines
        atom_list = []
        conect_list = []
        end_list = []
        for line in pdb_list:
            if line.startswith("ATOM"):
                atom_list.append(line)
            elif line.startswith("CONECT"):
                conect_list.append(line)
            elif line.startswith("END"):
                end_list.append(line)
            else:
                raise ValueError("PDB file contains unexpected line.")

        # sort atom_list by resid (columns 24 to 26)
        atom_list.sort(key=lambda x: int(x[23:26]))

        # combine atom_list and conect_list
        pdb_list = atom_list + conect_list + end_list

        # return the pdb file as a string
        return "\n".join(pdb_list)

    def _pdb_line_replace(
        self, line: str, atomname: str, resname: str, resid: int
    ) -> str:
        """Replaces atomname, resname, and resid of a single line in a pdb file.

        Parameters
        ----------
        line : str
            Single line of a pdb file.
        atomname : str
            Atom name to replace with.
        resname : str
            Residue name to replace with.
        resid : int
            Residue id to replace with.

        Returns
        -------
        str
            Pdb line with atomname, resname, and resid replaced.
        """
        # replace atom name (columns 14 to 16, left justified)
        line = self._replace(line, f"{atomname : <3}", 13, 16)
        # replace resname (columns 18 to 20, left justified)
        line = self._replace(line, f"{resname : <3}", 17, 20)
        # replace resid (columns 23 to 26, right justified)
        line = self._replace(line, f"{resid : >4}", 22, 26)

        return line

    @staticmethod
    def _replace(
        string: str, new_string: str, index_start: int, index_stop: int
    ) -> str:
        """Replaces characters between indices string s with new_string.

        Parameters
        ----------
        s : str
            String to replace character in.
        new_string : str
            String to replace character with.
        index_start : int
            Index of character to replace.
        index_stop : int
            Index of character to stop replacing.

        Returns
        -------
        str
            String with replaced characters.
        """
        return string[:index_start] + new_string + string[index_stop:]
