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
gmx_bin="/home/aglisman/software/gromacs_mpi_2023-plumed_mpi_2.9.0-gcc_12.3.0-cuda_12.0.140/bin/gmx_mpi"

# Gromacs files
mdp_file="../parameters/mdp/energy-minimization/em.mdp"
ff_dir="../force-field/eccrpa-force-fields/gaff.ff"

# Structure files
pdb_crystal_file="../initial-structure/calcium-carbonate-crystal/generation/python/calcite_297K-104_surface-2.99_3.22_3.66_nm_size-False_polar-True_symmetric.pdb"

# Simulation parameters
log_file='log.txt'
cpu_threads='16'
pin_offset='0'
gpu_ids='0'

# Output files
sim_name="energy_minimization"

# Copy input files to working directory ################################################
echo "INFO: Copying input files to working directory"

{
    # make symlink to force field
    ln -fs "${ff_dir}" "forcefield.ff"

    # copy files
    cp -p "${mdp_file}" "mdin.mdp"
    cp -p "${pdb_crystal_file}" "crystal.pdb"
} >>"${log_file}" 2>&1

# Import Structure to Gromacs ##########################################################
echo "INFO: Importing structure to Gromacs"

{
    # Create topology file
    "${gmx_bin}" -nocopyright -quiet pdb2gmx -v \
        -f "crystal.pdb" \
        -o "${sim_name}.gro" \
        -n "index.ndx" \
        -q "pdb2gmx_clean.pdb" \
        -ff "forcefield" \
        -water "spce" \
        -noignh \
        -renum \
        -rtpres
} >>"${log_file}" 2>&1

# Create TPR file ######################################################################
echo "INFO: Creating TPR file"

{
    # use grompp to create tpr file and full top file
    "${gmx_bin}" -nocopyright -quiet grompp -v \
        -f "mdin.mdp" \
        -n "index.ndx" \
        -c "${sim_name}.gro" \
        -p "topol.top" \
        -pp "topol_full.top" \
        -o "${sim_name}.tpr" \
        -maxwarn 0

    # copy input files to structure directory
    mkdir -p '0-structure'
    cp -p 'pdb2gmx_clean.pdb' '0-structure/system.pdb'
    cp -p 'topol_full.top' '0-structure/topol.top'
    cp -p 'index.ndx' '0-structure/index.ndx'
    cp -r 'posre.itp' '0-structure/posre.itp'

    # copy simulation files to simulation directory
    mkdir -p '1-energy-minimization'
    cp -p 'mdin.mdp' '1-energy-minimization/mdin.mdp'
    cp -p 'mdout.mdp' '1-energy-minimization/mdout.mdp'
    cp -p 'index.ndx' '1-energy-minimization/index.ndx'
    cp -p 'topol_full.top' '1-energy-minimization/topol.top'
    cp -p "${sim_name}.tpr" "1-energy-minimization/${sim_name}.tpr"
} >>"${log_file}" 2>&1

# Run Energy Minimization ##############################################################
echo "INFO: Running energy minimization"

{
    # run energy minimization
    "${gmx_bin}" -nocopyright -quiet mdrun -v \
        -deffnm "${sim_name}" \
        -nt "${cpu_threads}" -pin on -pinstride '1' -pinoffset "${pin_offset}" \
        -gpu_id "${gpu_ids}"
} >>"${log_file}" 2>&1

# Clean up #############################################################################
echo "INFO: Cleaning up"

{
    # copy files with pattern sim_name to simulation directory
    cp "${sim_name}."!(gro) -t "1-energy-minimization"
    rm "${sim_name}."!(gro)

    # delete all backup files
    find . -type f -name '#*#' -delete || true
} >>"${log_file}" 2>&1

echo "INFO: Energy minimization complete"
