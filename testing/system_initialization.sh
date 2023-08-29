#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-08-28
# Description: Script to create initial system for MD simulations
# Usage      : ./system_initialization.sh
# Notes      : Script may assume that some global variables are set (all caps)

# built-in shell options
set -o errexit  # exit when a command fails. Add || true to commands allowed to fail
set -o nounset  # exit when script tries to use undeclared variables
set -o pipefail # exit when a command in a pipe fails

# Default Preferences ###################################################################
echo "INFO: Setting default preferences"

# Executables
gmx_bin="/home/modules/gromacs_mpi_2023-plumed_mpi_2.9.0-gcc_self_12.3.0-cuda_12.2.128/bin/gmx_mpi"
mpi_bin="/home/modules/openmpi_4.1.5-gcc_12.3.0-cuda_12.2.128/bin/mpirun"

# Gromacs files
mdp_file="../parameters/mdp/energy-minimization/em.mdp"
ff_dir="../force-field/eccrpa-force-fields/gaff.ff"

# Structure files
pdb_crystal_file="../initial-structure/calcium-carbonate-crystal/supercell/calcite_297K-001_surface-2.00_2.16_3.41_nm_size-True_polar-False_symmetric.pdb"

# Output files
sim_name="energy_minimization"

# Copy input files to working directory ################################################
echo "INFO: Copying input files to working directory"

# make symlink to force field
ln -fs "${ff_dir}" "forcefield.ff"

# copy files
cp -p "${mdp_file}" "mdin.mdp"
cp -p "${pdb_crystal_file}" "crystal.pdb"

# Import Structure to Gromacs ##########################################################
echo "INFO: Importing structure to Gromacs"

# Create topology file
"${gmx_bin}" --nocopyright pdb2gmx -v \
    -f "crystal.pdb" \
    -o "${sim_name}.gro" \
    -n "index.ndx" \
    -q "pdb2gmx_clean.pdb" \
    -ff "forcefield" \
    -water "spce" \
    -noignh \
    -renum \
    -rtpres
