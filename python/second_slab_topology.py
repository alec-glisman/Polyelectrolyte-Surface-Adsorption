from pathlib import Path


class TwoSlabTopGenerator:

    def __init__(self, input_top: Path, verbose: bool = False) -> None:
        self.input_top = Path(input_top)
        with open(self.input_top, "r", encoding="utf-8") as f:
            self.top = f.read()

        # split top into dictionary of sections. Sections are separated by [section_name]
        self.sections = {}
        section_name = None
        for line in self.top.split("\n"):
            if line.startswith("["):
                section_name = line
                self.sections[section_name] = []
            else:
                self.sections[section_name].append(line)
        if verbose:
            print(f"Parsed sections: {self.sections.keys()}")

        self.generated_top = False

        # TODO: calculate the number of atoms in the system
        # TODO: calculate number of atoms in original slab

    def generate(self, output_top: Path) -> None:
        self._add_atoms()
        self._add_bonds()
        self._add_angles()
        self._add_dihedrals()
        self._add_position_restraints()

        self.generated_top = True
        self.save(output_top)

    def _add_atoms(self) -> None:
        pass

    def _add_bonds(self) -> None:
        pass

    def _add_angles(self) -> None:
        pass

    def _add_dihedrals(self) -> None:
        pass

    def _add_position_restraints(self) -> None:
        pass

    def save(self, output_top: Path) -> None:
        if not self.generated_top:
            raise ValueError("Topology has not been generated yet")
        with open(output_top, "w", encoding="utf-8") as f:
            f.write(self.top)
