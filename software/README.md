# Simulation Software

The [`software`](./../software) directory contains the source code for various simulation software packages.
We currently use gromacs 2022.3 patced with plumed 2.8.1.
Packmol 20.3.5 is used to generate initial configurations from `.pdb` files and Alan Grossfield's WHAM 2.0.11 is used to compare the WHAM outputs from the different software packages.

We have prepared installation scripts for Gromacs and Plumed, which are located in the [`installation-scripts`](./installation-scripts) directory.
Users are encouraged to use these scripts to install the software packages.
However, users should carefully review all script variables and adjust them as needed (such as installation location MPI usage, etc.).
The source code for the desired software packages must be unarchived before running the installation scripts.

More information on the specific environment used for the simulations can be found in the [`requirements`](./requirements) directory.
Python virtual environment files are provided in both `pip` and `conda` formats.
Spack environment files are also provided for users who wish to use Spack to install the software packages using `spack install` inside the [`spack`](./requirements//spack) directory.
Note that this feature is not tested frequently and may not work as expected.
