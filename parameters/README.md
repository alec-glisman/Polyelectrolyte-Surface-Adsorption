# Simulation Parameters

The [`parameters`](./../parameters) directory contains files specifying parameters for various aspects of the molecular dynamics simulations.
These files are used by the [`scripts`](./../scripts) to generate the inputs for the Plumed-patched Gromacs simulations.

[`mdp`](./mdp) contains the molecular dynamics parameters (MDP) for Gromacs.
File specifications are described in the [Gromacs manual](https://manual.gromacs.org/documentation/current/user-guide/mdp-options.html).
The file names are important, as they are used by the [`scripts`](./../scripts) to call `gmx grompp` on the `mdp` files to generate the input `tpr` files for the simulations.
The files are placed in subdirectories according to the type of simulation they are used for.
The files in [`umbrella-sampling`](./mdp/umbrella-sampling) are more generally useful for simulations where 2 polymer chains are desired to be restrained at a specific distance from each other.

[`plumed`](./plumed-mdrun) contains the input files for the [Plumed](https://www.plumed.org/) patch inside `gmx mdrun`.
These files should be called during a simulation with the `-plumed` flag.
We currently have template input files for simple harmonic restraints, OPES-Explore, HREMD, and OneOPES.
