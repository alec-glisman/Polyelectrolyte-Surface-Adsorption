# standard library
from argparse import ArgumentParser
from pathlib import Path

# third-party
import numpy as np
import gromacs as gmx


class TwoSlabIdxGenerator:

    def __init__(self, input_idx: Path, input_gro: Path, verbose: bool = False) -> None:
        # parse input index file
        self.ndx = gmx.fileformats.ndx.NDX()
        self.ndx.read(input_idx)

        # parse input gro file
        self.input_gro = Path(input_gro)
        with open(self.input_gro, "r", encoding="utf-8") as f:
            self.gro = f.read()
        self.n_atoms = int(self.gro.split("\n")[1])
        n_crb_atoms = len([line for line in self.gro.split("\n") if "CRB" in line])
        self.n_crystal_atoms = int(3 * n_crb_atoms / 2)

        if verbose:
            print(f"Number of atoms: {self.n_atoms}")
            print(f"Number of crystal atoms in first slab: {self.n_crystal_atoms}")
            print(f"Index groups: {self.ndx.keys()}")

    def _update_original_index(self, min_index: int, offset: int) -> None:
        # update original index for all groups with offset from second slab
        for group in self.ndx.keys():
            self.ndx[group] = [
                i + offset if i >= min_index else i for i in self.ndx[group]
            ]

    def _add_second_slab(self, min_index: int, n_atoms: int) -> None:
        # get atoms in frozen and mobile groups
        frozen = self.ndx["Frozen"]
        frozen_slab = frozen[frozen < min_index]
        mobile = self.ndx["Mobile"]
        mobile_slab = mobile[mobile < min_index]

        # TODO: add relevant atoms to frozen and mobile groups
        frozen_second_slab = [i + min_index for i in frozen_slab]
        mobile_second_slab = [i + min_index for i in mobile_slab]
        self.ndx["Frozen"] = np.append(frozen, frozen_second_slab)
        self.ndx["Mobile"] = np.append(mobile, mobile_second_slab)

        # FIXME: for all subgroups of "Crystal", only add relevant atoms
        # add second slab to all groups matching patterns
        patterns = ["Crystal", "System", "non-Water"]
        group_new = np.array([min_index + i for i in range(1, n_atoms + 1)])
        for group in self.ndx.items():
            group = group[0]
            if any(pattern in group for pattern in patterns):
                group_original = self.ndx[group]
                self.ndx[group] = np.append(group_original, group_new)

    def generate(self, output_top: Path) -> None:
        self._update_original_index(self.n_crystal_atoms, self.n_crystal_atoms)
        self._add_second_slab(self.n_crystal_atoms, self.n_crystal_atoms)
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
