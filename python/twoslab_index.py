# standard library
from argparse import ArgumentParser
from pathlib import Path

# third-party
import numpy as np
import gromacs as gmx


class TwoSlabIdxGenerator:

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

    def _update_original_index(self, min_index: int, offset: int) -> None:
        # update original index for all groups with offset from second slab
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
                f"Number of atoms mismatch in System group: {total_atoms} != {len(self.ndx['System'])}"
            )

    def _add_second_slab(self, min_index: int) -> None:
        # add second slab to all groups matching patterns
        patterns = ["System", "non-Water", "Frozen", "Mobile", "Crystal"]
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
                f"Number of atoms mismatch in System group: {total_atoms} != {len(self.ndx['System'])}"
            )

    def _sort(self) -> None:
        for key, value in self.ndx.items():
            self.ndx[key] = np.sort(value)

    def generate(self, output_top: Path) -> None:
        self._update_original_index(self.n_crystal_atoms, self.n_crystal_atoms)
        self._add_second_slab(self.n_crystal_atoms)
        self._sort()

        assert self.n_atoms + self.n_crystal_atoms == max(
            self.ndx["System"]
        ), f"Number of atoms mismatch in System group: {self.n_atoms} != {max(self.ndx['System'])}"

        self.save(output_top)

    def save(self, output_top: Path) -> None:
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
    generator.generate(args.output_idx)


if __name__ == "__main__":
    main()
