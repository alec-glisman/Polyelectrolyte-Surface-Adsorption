# Simulation Software

The [`software`](./../software) directory contains the source code for various simulation software packages.
We currently use gromacs 2023 patched with plumed 2.9.0.

We have prepared installation scripts for Gromacs and Plumed, which are located in the [`installation-scripts`](./installation-scripts) directory.
Users are encouraged to use these scripts to install the software packages.
However, users should carefully review all script variables and adjust them as needed (such as installation location MPI usage, etc.).

More information on the specific environment used for the simulations can be found in the [`requirements`](./requirements) directory.
Python virtual environment files are provided in `conda` format.
