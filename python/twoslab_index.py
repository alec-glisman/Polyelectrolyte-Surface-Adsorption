"""
This module provides a class for generating index files for a system with
two slabs.

The TwoSlabIdxGenerator class takes an input index file and an input gro file
as arguments and generates an index file for a system with two slabs. It
provides methods for updating the original index, adding the second slab to
groups matching patterns, sorting the indices, and saving the index file.

Example usage:
    generator = TwoSlabIdxGenerator(input_idx, input_gro)
    generator.generate(output_idx)

Attributes:
    input_idx (Path): The path to the input index file.
    input_gro (Path): The path to the input gro file.
    verbose (bool): Whether to print verbose output.

Methods:
    __init__(input_idx: Path, input_gro: Path, verbose: bool = True):
        Initializes the TwoSlabIdxGenerator object.
    __repr__(): Returns a string representation of the TwoSlabIdxGenerator
        object.
    print(): Prints the index groups and the number of atoms in each group.
    _update_original_index(min_index: int, offset: int): Updates the original
        index for all groups with an offset from the second slab.
    _add_second_slab(min_index: int): Adds the second slab to all groups
        matching patterns.
    _sort(): Sorts the indices in each group.
    generate(output_top: Path): Generates the index file for the system with
        two slabs.
    save(output_top: Path): Saves the index file to the specified path.
"""

# standard library
from argparse import ArgumentParser
from pathlib import Path

# third-party
import numpy as np
import gromacs as gmx


class TwoSlabIdxGenerator:
    """
    A class for generating index files for a system with two slabs.

    Args:
        input_idx (Path): The path to the input index file.
        input_gro (Path): The path to the input gro file.
        verbose (bool, optional): Whether to print verbose output. Defaults to True.

    Attributes:
        ndx (gmx.fileformats.ndx.NDX): The parsed input index file.
        input_gro (Path): The path to the input gro file.
        gro (str): The content of the input gro file.
        n_atoms (int): The total number of atoms in the system.
        n_crystal_atoms (int): The number of crystal atoms in the first slab.
        verbose (bool): Whether to print verbose output.

    Methods:
        __repr__(): Returns a string representation of the TwoSlabIdxGenerator object.
        print(): Prints the index groups and the number of atoms in each group.
        _update_original_index(min_index: int, offset: int): Updates the
            original index for all groups with an offset from the second slab.
        _add_second_slab(min_index: int): Adds the second slab to all groups
            matching patterns.
        _sort(): Sorts the indices in each group.
        generate(output_top: Path): Generates the index file for the system
            with two slabs.
        save(output_top: Path): Saves the index file to the specified path.
    """

    def __init__(self, input_idx: Path, input_gro: Path, verbose: bool = True) -> None:
        # parse input index file
        self.ndx = gmx.fileformats.ndx.NDX()
        self.ndx.read(input_idx)

        # parse input gro file
        self.input_gro = Path(input_gro)
        with open(self.input_gro, "r", encoding="utf-8") as f:
            self.gro = f.read()
        self.n_atoms = int(self.gro.split("\n")[1])
        self.n_crystal_atoms = len(self.ndx["Crystal"])

        # input validation
        total_atoms = self.n_atoms
        if total_atoms != len(self.ndx["System"]):
            raise ValueError(
                "Number of atoms mismatch in System group:"
                + f" {total_atoms} != {len(self.ndx['System'])}"
            )

        self.verbose = verbose
        if verbose:
            print(f"Number of atoms: {self.n_atoms}")
            print(f"Number of crystal atoms in first slab: {self.n_crystal_atoms}")
            print(f"Index groups: {self.ndx.keys()}")

    def __repr__(self) -> str:
        return (
            f"TwoSlabIdxGenerator(input_gro={self.input_gro},"
            + f" n_atoms={self.n_atoms},"
            + f" n_crystal_atoms={self.n_crystal_atoms},"
            + f" verbose={self.verbose})"
        )

    def print(self) -> None:
        """
        Prints the index groups and the number of atoms in each group.
        """
        for key, value in self.ndx.items():
            # left justify key with 25 columns
            print(f"  {key:<25}: {value} atoms")

    def _update_original_index(self, min_index: int, offset: int) -> None:
        """
        Updates the original index for all groups with an offset from the
        second slab.

        Args:
            min_index (int): The minimum index of the second slab.
            offset (int): The offset to be added to the indices.

        Raises:
            ValueError: If the number of atoms in the System group does not
            match the total number of atoms.
        """
        for key, value in self.ndx.items():
            updated = [i + offset if i > min_index else i for i in value]
            self.ndx[key] = np.array(updated, dtype=int)
            if self.verbose:
                n_changed = sum([i > min_index for i in value])
                if n_changed > 0:
                    print(f"Updated {n_changed} indices in group {key}")
                else:
                    print(f"No indices updated in group {key}")

        total_atoms = self.n_atoms
        if total_atoms != len(self.ndx["System"]):
            raise ValueError(
                "Number of atoms mismatch in System group:"
                + f" {total_atoms} != {len(self.ndx['System'])}"
            )

    def _add_second_slab(self, min_index: int) -> None:
        """
        Adds the second slab to all groups matching patterns.

        Args:
            min_index (int): The minimum index of the second slab.

        Raises:
            ValueError: If the number of atoms in the System group does not
            match the total number of atoms.
        """
        patterns = ["System", "non-Water", "non-Protein", "Frozen", "Mobile", "Crystal"]
        for key, value in self.ndx.items():
            if any(p in key for p in patterns):
                group_new = np.array(
                    [i + min_index for i in value if i <= min_index], dtype=int
                )
                if len(group_new) > 0:
                    self.ndx[key] = np.append(value, group_new, axis=0)
                if self.verbose and len(group_new) > 0:
                    print(f"Added {len(group_new)} atoms to group {key}")
                elif self.verbose:
                    print(f"No atoms added to group {key}")

        total_atoms = self.n_atoms + self.n_crystal_atoms
        if total_atoms != len(self.ndx["System"]):
            raise ValueError(
                "Number of atoms mismatch in System group:"
                + f" {total_atoms} != {len(self.ndx['System'])}"
            )

    def _sort(self) -> None:
        """
        Sorts the indices in each group.
        """
        for key, value in self.ndx.items():
            self.ndx[key] = np.sort(value)

    def generate(self, output_top: Path) -> None:
        """
        Generates the index file for the system with two slabs.

        Args:
            output_top (Path): The path to save the generated index file.

        Raises:
            ValueError: If the number of atoms in the System group does not
            match the total number of atoms.
        """
        self._update_original_index(self.n_crystal_atoms, self.n_crystal_atoms)
        self._add_second_slab(self.n_crystal_atoms)
        self._sort()
        self.save(output_top)

    def save(self, output_top: Path) -> None:
        """
        Saves the index file to the specified path.

        Args:
            output_top (Path): The path to save the index file.
        """
        self.ndx.write(output_top)


def main():
    parser = ArgumentParser(
        description="Generate a topology file for a system with two slabs"
    )
    parser.add_argument(
        "-i", "--input-idx", type=Path, required=True, help="Input index file"
    )
    parser.add_argument(
        "-g", "--input-gro", type=Path, required=True, help="Input coordinate file"
    )
    parser.add_argument(
        "-o", "--output-idx", type=Path, required=True, help="Output index file"
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Print extra information"
    )
    args = parser.parse_args()

    generator = TwoSlabIdxGenerator(args.input_idx, args.input_gro, args.verbose)
    if args.verbose:
        print("Initial index groups:")
        generator.print()
    generator.generate(args.output_idx)
    if args.verbose:
        print("Final index groups:")
        generator.print()


if __name__ == "__main__":
    main()
