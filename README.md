# Polyelectrolyte Ion Adsorption

**Summary:** PLUMED-patched GROMACS molecular dynamics simulations repository used for my anti-scaling research project in the Wang Group.  
**Authors:** [Alec Glisman](https://github.com/alec-glisman)  
**GitHub actions:**
[![Code Linting](https://github.com/zgw-group/Polyelectrolyte-Ion-Adsorption/actions/workflows/code-linting.yml/badge.svg)](https://github.com/zgw-group/Polyelectrolyte-Ion-Adsorption/actions/workflows/code-linting.yml)
[![Language Linting](https://github.com/zgw-group/Polyelectrolyte-Ion-Adsorption/actions/workflows/language-linting.yml/badge.svg)](https://github.com/zgw-group/Polyelectrolyte-Ion-Adsorption/actions/workflows/language-linting.yml)  
**Third-party services:**
[![wakatime](https://wakatime.com/badge/github/alec-glisman/gromacs.svg)](https://wakatime.com/badge/github/alec-glisman/gromacs)

## Project structure

Each subdirectory contains its own `README.md` file with more detailed information about the project.
We present a brief summary of each subdirectory below, but strongly recommend that users read the other documentation for a better idea of how to use the code.

The project contains many configuration and styling files for various tools, including:

* [`.github/`](./.github/READ.md): GitHub workflows and issue templates directory.
* [`.vscode/`](./.vscode/README.md): Visual Studio Code editor settings and configuration directory.
* `.clang-format`: Clang-format configuration file for C++ code.
* `.pylintrc`: Pylint configuration file for Python code.
* `.shellcheckrc`: ShellCheck configuration file for shell scripts.
* `.wakatime-project`: Wakatime configuration file for time tracking.
* `CITATIONS.md`: List of citations for the project.
* `LICENSE`: Project license file.

The molecular dynamics simulations are contained in the following subdirectories:

* [`archive`](./archive/README.md): Old and deprecated code that may be useful for future reference.
* [`data`](./data/README.md): Data files output from simulation.
* [`force-fields`](./force-field/README.md): Force fields in GROMACS format used to model various system components.
* [`initial-structure`](./intial-structure/README.md): Energy minimized initial structures for polyelectrolytes and crystalline lattices.
* [`parameters`](./parameters/README.md): GROMACS mdp parameter files and simulation pipeline input variables.
* [`python`](./python/README.md): Helper Python scripts called by the simulation pipeline.
* [`scripts`](./scripts/README.md): Bash scripts used to run simulations and analyze data output using GROMACS and PLUMED command line interface tools.
* [`software`](./software/README.md): GROMACS and PLUMED source code and build scripts as well as environment configuration files.
* [`submission`](./submission/README.md): Slurm job submission scripts used to run simulations on the group's HPC cluster.

### Configuration

Various formatting files are included (`.clang-format`, `.pylintrc`, and `.shelcheckrc`) to ensure consistent code formatting and style.

## Software and environment

Further information on exact software versions can be found in the `software` directory's [`README.md`](software/README.md) file.
We run our simulations using

* Bash 5.1.16
* CMake 3.22.1
* CUDA 11.8
* GCC 10.4.0
* Gromacs 2022.3 (Plumed patched and user patched `share/top/residuetypes.dat`)
* Packmol 20.010
* Plumed 2.8.1
* Python 3.10.6

## Nomenclature

### Chemistry

* Asp: Aspartic acid
* Glu: Glutamic acid
* Acr: Acrylic acid
* P: Poly, as in polymer
* mer: Monomer

### Numerical

* EM: Energy minimization

### Statistical mechanics

* NVE: Microcanonical ensemble
* NVT: Canonical ensemble
* NPT: Isothermal–isobaric ensemble
