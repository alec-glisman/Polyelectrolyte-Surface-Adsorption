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
mpi_bin="/home/aglisman/software/openmpi_4.1.5-gcc_12.3.0-cuda_12.0.140/bin/mpirun"
gmx_bin="/home/aglisman/software/gromacs_mpi_2023-plumed_mpi_2.9.0-gcc_12.3.0-cuda_12.0.140/bin/gmx_mpi"

# Hardware parameters
cpu_threads='16'
pin_offset='0'
gpu_ids='0'

# System parameters
N_MONOMER='3'
N_CHAIN='3'
N_CARBONATE='2'
N_SODIUM='9'
N_CALCIUM='4'
N_CHLORINE='4'

echo "Total positive charge: $(bc <<<"${N_SODIUM} + 2*${N_CALCIUM}")"
echo "Total negative charge: $(bc <<<"-${N_CHLORINE} - 2*${N_CARBONATE} - ${N_MONOMER}*${N_CHAIN}")"

# Gromacs files
mdp_file="../parameters/mdp/energy-minimization/em.mdp"
ff_dir="../force-field/eccrpa-force-fields/gaff.ff"

# find path to this script
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Structure files
PDB_CRYSTAL="../initial-structure/calcium-carbonate-crystal/generation/python/calcite_297K-104_surface-2.99_3.22_3.66_nm_size-False_polar-True_symmetric.pdb"
PDB_CHAIN="../initial-structure/polyelectrolyte/chain/homopolymer/PAcr-3mer-atactic-Hend.pdb"
PACKMOL_INPUT="../parameters/packmol/crystal_surface.inp"

# Default structure files
structure_path="${script_path}/../initial-structure"
PDB_CARBONATE="${structure_path}/polyatomic-ions/carbonate_ion.pdb"
GRO_WATER="spc216.gro"

# Output files
cwd="$(pwd)"
sim_name="energy_minimization"
log_file="${sim_name}.log"

# Copy input files to working directory ################################################
echo "INFO: Copying input files to working directory"

{
    # move to working directory
    cd "${cwd}" || exit

    # copy force field files
    mkdir -p "forcefield.ff"
    cp -rp "${ff_dir}/"* -t "forcefield.ff"

    # copy files
    cp -p "${mdp_file}" "mdin.mdp"
    cp -p "${PDB_CRYSTAL}" "crystal.pdb"
    cp -p "${PDB_CHAIN}" "chain.pdb"
    cp -p "${PACKMOL_INPUT}" "packmol.inp"
} >>"${log_file}" 2>&1

# Import Structure to Gromacs ##########################################################
echo "INFO: Importing structure to Gromacs"

{
    # insert-molecules to create simulation box of crystal and chains
    "${gmx_bin}" -nocopyright -quiet insert-molecules \
        -f "crystal.pdb" \
        -ci "chain.pdb" \
        -o "${sim_name}.pdb" \
        -nmol "${N_CHAIN}" \
        -radius '0.5' \
        -try '100'

    # insert-molecules to add carbonate ions
    if [[ "${N_CARBONATE}" -gt 0 ]]; then
        "${gmx_bin}" -quiet insert-molecules \
            -f "${sim_name}.pdb" \
            -ci "${PDB_CARBONATE}" \
            -o "${sim_name}.pdb" \
            -nmol "${N_CARBONATE}" \
            -radius '0.5' \
            -try '100'
    fi

    # convert pdb to gro
    "${gmx_bin}" -nocopyright -quiet pdb2gmx -v \
        -f "${sim_name}.pdb" \
        -o "${sim_name}.gro" \
        -n "index.ndx" \
        -q "pdb2gmx_clean.pdb" \
        -ff "forcefield" \
        -water "spce" \
        -noignh \
        -renum \
        -rtpres
} >>"${log_file}" 2>&1

# Add Solvent #########################################################################
echo "INFO: Adding solvent"
{
    # add solvent
    "${gmx_bin}" -nocopyright -quiet solvate \
        -cp "${sim_name}.gro" \
        -cs "${GRO_WATER}" \
        -o "${sim_name}.gro" \
        -p "topol.top"

    # create index file
    "${gmx_bin}" -quiet make_ndx \
        -f "${sim_name}.gro" \
        -o "index.ndx" \
        <<EOF
q
EOF
} >>"${log_file}" 2>&1

# Add Ions ############################################################################
echo "INFO: Adding calcium ions"
{
    # add Ca2+ ions
    if [[ "${N_CALCIUM}" -gt 0 ]]; then
        # tpr update
        "${gmx_bin}" -nocopyright -quiet grompp \
            -f "mdin.mdp" \
            -c "${sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        # add ions
        "${gmx_bin}" --nocopyright -quiet genion \
            -s "${sim_name}.tpr" \
            -p "topol.top" \
            -o "${sim_name}.gro" \
            -pname "CA" \
            -np "${N_CALCIUM}" \
            -rmin "0.6" \
            <<EOF
SOL
EOF
    fi
} >>"${log_file}" 2>&1

echo "INFO: Adding sodium ions"
{
    # add Na+ ions
    if [[ "${N_SODIUM}" -gt 0 ]]; then
        # tpr update
        "${gmx_bin}" -nocopyright -quiet grompp \
            -f "mdin.mdp" \
            -c "${sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        # add ions
        "${gmx_bin}" --nocopyright -quiet genion \
            -s "${sim_name}.tpr" \
            -p "topol.top" \
            -o "${sim_name}.gro" \
            -pname "NA" \
            -np "${N_SODIUM}" \
            -rmin "0.6" \
            <<EOF
SOL
EOF
    fi
} >>"${log_file}" 2>&1

echo "INFO: Adding chlorine ions"
{
    # add Cl- ions
    if [[ "${N_CHLORINE}" -gt 0 ]]; then
        # tpr update
        "${gmx_bin}" -nocopyright -quiet grompp \
            -f "mdin.mdp" \
            -c "${sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        # add ions
        "${gmx_bin}" --nocopyright -quiet genion \
            -s "${sim_name}.tpr" \
            -p "topol.top" \
            -o "${sim_name}.gro" \
            -nname "CL" \
            -nn "${N_CHLORINE}" \
            -rmin "0.6" \
            <<EOF
SOL
EOF
    fi
} >>"${log_file}" 2>&1

# Create Topology #####################################################################
echo "INFO: Creating topology"
{
    # remake tpr file
    "${gmx_bin}" -quiet grompp \
        -f "mdin.mdp" \
        -c "${sim_name}.gro" \
        -p "topol.top" \
        -pp "topol_full.top" \
        -o "${sim_name}.tpr" \
        -maxwarn '1'

    # TODO: remake index file

} >>"${log_file}" 2>&1

# Create TPR file ######################################################################
echo "INFO: Archiving files"

{
    # copy input files to structure directory
    mkdir -p '0-structure'
    cp -p 'pdb2gmx_clean.pdb' '0-structure/system.pdb'
    cp -p 'topol_full.top' '0-structure/topol.top'
    cp -p 'index.ndx' '0-structure/index.ndx'
    cp -rp ./*.itp '0-structure/'

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
    "${mpi_bin}" -np 1 \
        --map-by "ppr:1:node:PE=${cpu_threads}" \
        --use-hwthread-cpus --bind-to 'hwthread' --report-bindings \
        "${gmx_bin}" -quiet -nocopyright mdrun -v \
        -deffnm "${sim_name}" \
        -pin on -pinoffset "${pin_offset}" -pinstride 1 -ntomp "${cpu_threads}" \
        -gpu_id "${gpu_ids}"

    # dump last frame of energy minimization as pdb file
    "${gmx_bin}" -quiet -nocopyright trjconv \
        -f "${sim_name}.trr" \
        -s "${sim_name}.tpr" \
        -o "${sim_name}_final.pdb" \
        -pbc 'mol' -center -ur 'compact' \
        -dump '10000' -conect <<EOF
System
System
EOF

} >>"${log_file}" 2>&1

# Clean up #############################################################################
echo "INFO: Cleaning up"

{
    # copy files with pattern sim_name to simulation directory
    cp -p "${sim_name}."* -t "1-energy-minimization"
    cp -p "${sim_name}.gro" -t "0-structure"
    rm "${sim_name}."*

    # delete all backup files
    find . -type f -name '#*#' -delete || true

    # delete other files that are not needed
    rm -r ./*.mdp ./*.itp index.ndx step*.pdb

    #
} >>"${log_file}" 2>&1

echo "INFO: Energy minimization complete"
