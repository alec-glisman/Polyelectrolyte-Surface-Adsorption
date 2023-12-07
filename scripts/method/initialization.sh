#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-08-28
# Description: Script to create initial system for MD simulations
# Usage      : ./system_initialization.sh
# Notes      : Script assumes that global variables have been set in a
#             submission/input/*.sh script. Script should only be called from
#             the main run.sh script.

# built-in shell options
set -o errexit  # exit when a command fails. Add || true to commands allowed to fail
set -o nounset  # exit when script tries to use undeclared variables
set -o pipefail # exit when a command in a pipe fails

# ##############################################################################
# Default Preferences ##########################################################
# ##############################################################################
echo "INFO: Setting default preferences"

# find path to this script
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
project_path="${script_path}/../.."
structure_path="${project_path}/initial-structure"

# Gromacs files
mdp_file="${project_path}/parameters/mdp/energy-minimization/em.mdp"
ion_mdp_file="${project_path}/parameters/mdp/energy-minimization/ions.mdp"

# Default structure files
pdb_carbonate="${structure_path}/polyatomic-ions/carbonate_ion.pdb"
gro_water="spc216.gro"

# Output files
cwd_initialization="$(pwd)"
cwd="$(pwd)/1-energy-minimization"
sim_name="energy_minimization"
log_file="system_initialization.log"

# ##############################################################################
# Check for existing files #####################################################
# ##############################################################################
echo "CRITICAL: Starting system initialization"

# move to working directory
mkdir -p "${cwd}"
cd "${cwd}" || exit

# see if "2-output/system.gro" exists
if [[ -f "2-output/system.gro" ]]; then
    echo "WARNING: 2-output/system.gro already exists"

    n_system="$(grep " System " "${log_file}" | tail -n 1 | awk '{print $4}')"

    # output the number of water molecules
    n_water="$(grep " Water " "${log_file}" | tail -n 1 | awk '{print $4}')"
    n_water=$((n_water / 3))

    # output number of atoms in system from number of values in index.ndx
    n_crystal_atoms="$(grep "Crystal " "${log_file}" | tail -n 1 | awk '{print $4}')"
    n_crystal_residues="$(bc <<<"scale=5; ${n_crystal_atoms} * 2.0 / 5.0")"
    n_crystal_residues="${n_crystal_residues%.*}"

    n_na="$(grep "Aqueous_Sodium " "${log_file}" | tail -n 1 | awk '{print $4}')" || n_na='0'
    n_ca="$(grep "Aqueous_Calcium " "${log_file}" | tail -n 1 | awk '{print $4}')" || n_ca='0'
    n_cl="$(grep "Aqueous_Chloride " "${log_file}" | tail -n 1 | awk '{print $4}')" || n_cl='0'
    n_carbonate="$(grep "Aqueous_Carbonate " "${log_file}" | tail -n 1 | awk '{print $4}')" || n_carbonate='0'

    echo "DEBUG: Total number of atoms: ${n_system}"
    echo "DEBUG: Number of crystal (CaCO3) atoms: ${n_crystal_atoms}"
    echo "DEBUG: Number of crystal (CaCO3) residues: ${n_crystal_residues}"
    echo "DEBUG: Number of aqueous sodium ions: ${n_na}"
    echo "DEBUG: Number of aqueous calcium ions: ${n_ca}"
    echo "DEBUG: Number of aqueous chloride ions: ${n_cl}"
    echo "DEBUG: Number of aqueous carbonate ions: ${n_carbonate}"

    echo "INFO: Exiting script"
    exit 0
fi

# ##############################################################################
# Copy input files to working directory ########################################
# ##############################################################################
echo "INFO: Copying input files to working directory"

{
    # copy force field files
    mkdir -p "forcefield.ff"
    cp -rp "${FF_DIR}/"* -t "forcefield.ff" || exit 1

    # copy files
    # if any cp commands failed, exit script
    cp -np "${mdp_file}" "mdin.mdp" || exit 1
    cp -np "${PDB_CRYSTAL}" "crystal.pdb" || exit 1
    cp -np "${PDB_CHAIN}" "chain.pdb" || exit 1

} >>"${log_file}" 2>&1

# ##############################################################################
# Import Structure to Gromacs ##################################################
# ##############################################################################
echo "INFO: Importing structure to Gromacs"

{
    # insert-molecules to create simulation box of crystal and chains
    if [[ "${N_CHAIN}" -gt 0 ]]; then
        "${GMX_BIN}" -nocopyright insert-molecules \
            -f "crystal.pdb" \
            -ci "chain.pdb" \
            -o "${sim_name}.pdb" \
            -nmol "${N_CHAIN}" \
            -radius '20' \
            -try '10000'
    else
        cp -np "crystal.pdb" "${sim_name}.pdb"
    fi

    # insert-molecules to add carbonate ions
    # shellcheck disable=SC2153
    if [[ "${N_CARBONATE}" -gt 0 ]]; then
        "${GMX_BIN}" insert-molecules \
            -f "${sim_name}.pdb" \
            -ci "${pdb_carbonate}" \
            -o "${sim_name}.pdb" \
            -nmol "${N_CARBONATE}" \
            -radius '20' \
            -try '10000'
    fi

    # convert pdb to gro
    "${GMX_BIN}" -nocopyright pdb2gmx -v \
        -f "${sim_name}.pdb" \
        -o "${sim_name}.gro" \
        -n "index.ndx" \
        -q "pdb2gmx_clean.pdb" \
        -ff "forcefield" \
        -water "spce" \
        -noignh \
        -renum \
        -rtpres

    # get box dimensions from last line of gro file
    box_dim="$(tail -n 1 "${sim_name}.gro")"
    z="$(echo "${box_dim}" | awk '{print $3}')"
    new_z="$(bc <<<"scale=5; ${BOX_HEIGHT} * 1.00000")"

    # increase z-dimension of box to BOX_HEIGHT by string replacement of 3rd column in last line of gro file
    sed -i "s/${z}/${new_z}/g" "${sim_name}.gro"

    # find minimum z-coordinate of crystal by last 6 columns of each CRB containing line in gro file
    carbonate_carbon_z="$(grep 'CRB' "${sim_name}.gro" | grep -o '.\{6\}$' | awk '{$1=$1};1')"
    minimum_z_coord="$(echo "${carbonate_carbon_z}" | sort -n)"
    z_min="$(echo "${minimum_z_coord}" | awk 'NR==1{print $1}')"
    # subtract 1.5 nm to z_min to ensure that all atoms are within the box and we can see water structure
    offset='1.5'
    z_min="$(bc <<<"scale=5; ${z_min} - ${offset}")"

    # shift z-coordinates of all atoms by z_min
    "${GMX_BIN}" -nocopyright editconf \
        -f "${sim_name}.gro" \
        -o "${sim_name}.gro" \
        -translate '0' '0' "-${z_min}"

    # wrap all atoms into box
    "${GMX_BIN}" -nocopyright trjconv \
        -f "${sim_name}.gro" \
        -s "${sim_name}.gro" \
        -o "${sim_name}.gro" \
        -pbc 'atom' <<EOF
System
EOF
} >>"${log_file}" 2>&1

echo "DEBUG: Initial box height [A]: ${z}"
echo "DEBUG: Final box height [A]: ${new_z}"
echo "DEBUG: Minimum z-coordinate of crystal initially [nm]: ${z_min}"

# ##############################################################################
# Add Solvent ##################################################################
# ##############################################################################
echo "INFO: Adding solvent"
{
    # add solvent
    "${GMX_BIN}" -nocopyright solvate \
        -cp "${sim_name}.gro" \
        -cs "${gro_water}" \
        -o "${sim_name}.gro" \
        -p "topol.top"

    # subtract z_min from pdb bulk z-coordinates and add buffer for outer layers
    buffer='0.3'
    gro_zmin="$(bc <<<"scale=5; ${PDB_BULK_ZMIN} - ${z_min} - ${buffer}")"
    gro_zmax="$(bc <<<"scale=5; ${PDB_BULK_ZMAX} - ${z_min} + ${buffer}")"

    # find "bad" water molecules that are inside the crystal
    "${GMX_BIN}" -nocopyright select \
        -f "${sim_name}.gro" \
        -s "${sim_name}.gro" \
        -on "bad_waters.ndx" <<EOF
"Bad_SOL" same residue as (name OW HW1 HW2 and (z >= ${gro_zmin} and z <= ${gro_zmax}))
EOF
    # remove "f0_t0.000" from index file groups
    sed -i 's/_f0_t0.000//g' "bad_waters.ndx"
    # make complement index file
    "${GMX_BIN}" make_ndx \
        -f "${sim_name}.gro" \
        -n "bad_waters.ndx" \
        -o "bad_waters.ndx" \
        <<EOF
! 0
name 1 Good_Atoms
q
EOF

    # remove "bad" water molecules from gro file
    "${GMX_BIN}" -nocopyright trjconv \
        -f "${sim_name}.gro" \
        -s "${sim_name}.gro" \
        -o "${sim_name}.gro" \
        -n "bad_waters.ndx" \
        -pbc 'atom' -ur 'tric' <<EOF
Good_Atoms
EOF
} >>"${log_file}" 2>&1

echo "DEBUG: Minimum z-coordinate of crystal after solvation [nm]: ${gro_zmin}"
echo "DEBUG: Maximum z-coordinate of crystal after solvation [nm]: ${gro_zmax}"

# find number of "bad" water molecules from log file
n_bad_atoms="$(grep "Bad_SOL" "${log_file}" | head -n 1 | awk '{print $4}')"
n_bad_waters="$((n_bad_atoms / 3))"
echo "DEBUG: Number of water molecules inside crystal (removed): ${n_bad_waters}"

{
    # remove n_bad_waters from topol.top file
    n_waters="$(grep "SOL" "topol.top" | awk '{print $2}')"
    n_waters="$((n_waters - n_bad_waters))"
    sed -i "s/SOL "'.*'"/SOL ${n_waters} ; ${n_bad_waters} bad waters removed/g" "topol.top"

    # copy output files
    cp -np "${sim_name}.gro" "solvated.gro" || exit 1

    # create index file
    "${GMX_BIN}" make_ndx \
        -f "${sim_name}.gro" \
        -o "index.ndx" \
        <<EOF
q
EOF
} >>"${log_file}" 2>&1

# ##############################################################################
# Add Ions #####################################################################
# ##############################################################################
echo "INFO: Adding calcium ions"
{
    # add Ca2+ ions
    if [[ "${N_CALCIUM}" -gt 0 ]]; then
        # tpr update
        "${GMX_BIN}" -nocopyright grompp \
            -f "${ion_mdp_file}" \
            -c "${sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        # add ions
        "${GMX_BIN}" --nocopyright genion \
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
        "${GMX_BIN}" -nocopyright grompp \
            -f "${ion_mdp_file}" \
            -c "${sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        # add ions
        "${GMX_BIN}" --nocopyright genion \
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
        "${GMX_BIN}" -nocopyright grompp \
            -f "${ion_mdp_file}" \
            -c "${sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        # add ions
        "${GMX_BIN}" --nocopyright genion \
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

echo "INFO: Create topology file with all solutes"
{
    # tpr file
    "${GMX_BIN}" -nocopyright grompp \
        -f "${ion_mdp_file}" \
        -c "${sim_name}.gro" \
        -p "topol.top" \
        -o "${sim_name}.tpr"

    # pdb file
    "${GMX_BIN}" -nocopyright trjconv \
        -f "${sim_name}.gro" \
        -s "${sim_name}.tpr" \
        -o "${sim_name}.pdb" \
        -pbc 'mol' -ur 'tric' \
        -conect <<EOF
System
EOF
} >>"${log_file}" 2>&1

# ##############################################################################
# Make Index File ##############################################################
# ##############################################################################
echo "INFO: Making index file"

{
    # create blank index file
    idx_group='17'
    "${GMX_BIN}" make_ndx \
        -f "${sim_name}.gro" \
        -o "index.ndx" \
        <<EOF
q
EOF

    # clear index_crystal.ndx file
    # shellcheck disable=SC2188
    >"index_crystal.ndx" || true

    # add crystal groups to index file
    "${GMX_BIN}" select \
        -f "crystal.pdb" \
        -s "crystal.pdb" \
        -n "index.ndx" \
        -on "index_crystal.ndx" \
        <<EOF
"Crystal" resname CRB CA
"Crystal_Bulk" same residue as (name CX1 CA and (z >= ${PDB_BULK_ZMIN} and z <= ${PDB_BULK_ZMAX}))
"Top_Crystal_Surface" same residue as (name CX1 CA and (z > ${PDB_BULK_ZMAX}))
"Bottom_Crystal_Surface" same residue as (name CX1 CA and (z < ${PDB_BULK_ZMIN}))
EOF
    # save group numbers
    group_bulk="$((idx_group + 1))"
    group_top_surface="$((idx_group + 2))"
    group_bottom_surface="$((idx_group + 3))"

    # remove "f0_t0.000" from index file groups
    sed -i 's/_f0_t0.000//g' "index_crystal.ndx"
    # append crystal groups to index file
    cat "index_crystal.ndx" >>"index.ndx"
    idx_group=$((idx_group + 4))

    # add crystal sub-groups to index file
    "${GMX_BIN}" make_ndx \
        -f "crystal.pdb" \
        -n "index.ndx" \
        -o "index.ndx" \
        <<EOF
${group_bulk} & ! a CA*
name ${idx_group} Crystal_Bulk_Carbonate
${group_bulk} & a CX*
name $((idx_group + 1)) Crystal_Bulk_Carbonate_Carbon
${group_bulk} & a OX*
name $((idx_group + 2)) Crystal_Bulk_Carbonate_Oxygen
${group_bulk} & a O*
name $((idx_group + 3)) Crystal_Bulk_Calcium
${group_top_surface} & ! a CA*
name $((idx_group + 4)) Crystal_Top_Surface_Carbonate
${group_top_surface} & a CX*
name $((idx_group + 5)) Crystal_Top_Surface_Carbonate_Carbon
${group_top_surface} & a OX*
name $((idx_group + 6)) Crystal_Top_Surface_Carbonate_Oxygen
${group_top_surface} & a O*
name $((idx_group + 7)) Crystal_Top_Surface_Calcium
${group_top_surface} & ! a CA*
name $((idx_group + 8)) Crystal_Bottom_Surface_Carbonate
${group_top_surface} & a CX*
name $((idx_group + 9)) Crystal_Bottom_Surface_Carbonate_Carbon
${group_top_surface} & a OX*
name $((idx_group + 10)) Crystal_Bottom_Surface_Carbonate_Oxygen
${group_top_surface} & a O*
name $((idx_group + 11)) Crystal_Bottom_Surface_Calcium

q
EOF
    idx_group=$((idx_group + 12))

    # add system section groups to index file
    "${GMX_BIN}" make_ndx \
        -f "${sim_name}.pdb" \
        -n "index.ndx" \
        -o "index.ndx" \
        <<EOF
${group_bulk}
name $((idx_group)) Frozen
! ${group_bulk}
name $((idx_group + 1)) Mobile 
! ${group_bulk} & ! ${group_top_surface} & ! ${group_bottom_surface}
name $((idx_group + 2)) Aqueous

q
EOF
    idx_group=$((idx_group + 3))

    # add chain groups to index file
    if [[ "${N_CHAIN}" -gt 0 ]]; then
        "${GMX_BIN}" make_ndx \
            -f "pdb2gmx_clean.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a * & chain A
name ${idx_group} Chain
a O* & chain A
name $((idx_group + 1)) Chain_Oxygen

q
EOF
        idx_group=$((idx_group + 2))
    fi

    # add aqueous sodium ions to index file
    if [[ "${N_SODIUM}" -gt 0 ]]; then
        "${GMX_BIN}" make_ndx \
            -f "${sim_name}.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a NA & ! chain A & ! chain B
name ${idx_group} Aqueous_Sodium

q
EOF
        idx_group=$((idx_group + 1))
    fi

    # add aqueous calcium ions to index file
    if [[ "${N_CALCIUM}" -gt 0 ]]; then
        "${GMX_BIN}" make_ndx \
            -f "${sim_name}.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a CA & ! chain A & ! chain B
name ${idx_group} Aqueous_Calcium

q
EOF
        idx_group=$((idx_group + 1))
    fi

    # add aqueous chloride ions to index file
    if [[ "${N_CHLORINE}" -gt 0 ]]; then
        "${GMX_BIN}" make_ndx \
            -f "${sim_name}.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a CL & ! chain A & ! chain B
name ${idx_group} Aqueous_Chloride
q
EOF
        idx_group=$((idx_group + 1))
    fi

    # add aqueous carbonate ions to index file
    if [[ "${N_CARBONATE}" -gt 0 ]]; then
        "${GMX_BIN}" make_ndx \
            -f "${sim_name}.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a CX* | a OX* & ! chain A & ! chain B
name ${idx_group} Aqueous_Carbonate
a CX* & ! chain A & ! chain B
name $((idx_group + 1)) Aqueous_Carbonate_Carbon
a OX* & ! chain A & ! chain B
name $((idx_group + 2)) Aqueous_Carbonate_Oxygen

q
EOF
        idx_group=$((idx_group + 3))
    fi

} >>"${log_file}" 2>&1

# ##############################################################################
# Add positional restraints ####################################################
# ##############################################################################
echo "INFO: Adding positional restraints"

{
    # change POSRES default to component specific POSRES
    sed -i 's/POSRES/POSRES_CRYSTAL/g' topol_Ion_chain_*.itp
    sed -i 's/POSRES/POSRES_CHAIN/g' topol_Protein_chain_*.itp
}

# ##############################################################################
# Create Topology ##############################################################
# ##############################################################################
echo "INFO: Creating topology file with all parameters merged"
{
    # print index file to log
    "${GMX_BIN}" make_ndx \
        -f "${sim_name}.pdb" \
        -n "index.ndx" \
        -o "index.ndx" \
        <<EOF
l
q
EOF

    # remake tpr file and topology file with no imports
    "${GMX_BIN}" grompp \
        -f "mdin.mdp" \
        -c "${sim_name}.gro" \
        -r "${sim_name}.gro" \
        -n "index.ndx" \
        -p "topol.top" \
        -pp "topol_full.top" \
        -o "${sim_name}.tpr"
} >>"${log_file}" 2>&1

n_system="$(grep " System " "${log_file}" | tail -n 1 | awk '{print $4}')"

# output the number of water molecules
n_water="$(grep " Water " "${log_file}" | tail -n 1 | awk '{print $4}')"
n_water=$((n_water / 3))
echo "DEBUG: Number of water molecules: ${n_water}"

# output number of atoms in system from number of values in index.ndx
n_crystal_atoms="$(grep "Crystal " "${log_file}" | tail -n 1 | awk '{print $4}')"
n_crystal_residues="$(bc <<<"scale=5; ${n_crystal_atoms} * 2.0 / 5.0")"
n_crystal_residues="${n_crystal_residues%.*}"

n_na="$(grep "Aqueous_Sodium " "${log_file}" | tail -n 1 | awk '{print $4}')" || n_na='0'
n_ca="$(grep "Aqueous_Calcium " "${log_file}" | tail -n 1 | awk '{print $4}')" || n_ca='0'
n_cl="$(grep "Aqueous_Chloride " "${log_file}" | tail -n 1 | awk '{print $4}')" || n_cl='0'
n_carbonate="$(grep "Aqueous_Carbonate " "${log_file}" | tail -n 1 | awk '{print $4}')" || n_carbonate='0'

echo "DEBUG: Total number of atoms: ${n_system}"
echo "DEBUG: Number of crystal (CaCO3) atoms: ${n_crystal_atoms}"
echo "DEBUG: Number of crystal (CaCO3) residues: ${n_crystal_residues}"
echo "DEBUG: Number of aqueous sodium ions: ${n_na}"
echo "DEBUG: Number of aqueous calcium ions: ${n_ca}"
echo "DEBUG: Number of aqueous chloride ions: ${n_cl}"
echo "DEBUG: Number of aqueous carbonate ions: ${n_carbonate}"

# ##############################################################################
# Archive data #################################################################
# ##############################################################################
echo "INFO: Archiving files"

{
    # copy input files to structure directory
    mkdir -p '0-structure'
    cp -np 'pdb2gmx_clean.pdb' '0-structure/system.pdb' || exit 1
    cp -np 'topol_full.top' '0-structure/topol.top' || exit 1
    cp -np 'index.ndx' '0-structure/index.ndx' || exit 1
    cp -rp ./*.itp '0-structure/' || exit 1

    # copy simulation files to simulation directory
    mkdir -p '1-energy-minimization'
    cp -np 'mdin.mdp' '1-energy-minimization/mdin.mdp' || exit 1
    cp -np 'mdout.mdp' '1-energy-minimization/mdout.mdp' || exit 1
    cp -np 'index.ndx' '1-energy-minimization/index.ndx' || exit 1
    cp -np 'topol_full.top' '1-energy-minimization/topol.top' || exit 1
    cp -np "${sim_name}.tpr" "1-energy-minimization/${sim_name}.tpr" || exit 1
} >>"${log_file}" 2>&1

# ##############################################################################
# Run Energy Minimization ######################################################
# ##############################################################################
echo "INFO: Running energy minimization"

{
    # run energy minimization
    # shellcheck disable=SC2086
    "${MPI_BIN}" -np '1' \
        --map-by "ppr:1:node:PE=${CPU_THREADS}" \
        --use-hwthread-cpus --bind-to 'hwthread' \
        "${GMX_BIN}" -nocopyright mdrun -v \
        -deffnm "${sim_name}" \
        ${GMX_CPU_ARGS} ${GMX_GPU_ARGS} || exit 1

    # dump last frame of energy minimization as gro file
    "${GMX_BIN}" -nocopyright trjconv \
        -f "${sim_name}.trr" \
        -s "${sim_name}.tpr" \
        -o "${sim_name}.gro" \
        -dump '100000' <<EOF
System
EOF

    # dump last frame of energy minimization as pdb file
    "${GMX_BIN}" -nocopyright trjconv \
        -f "${sim_name}.trr" \
        -s "${sim_name}.tpr" \
        -o "${sim_name}_final.pdb" \
        -pbc 'mol' -ur 'tric' \
        -dump '100000' -conect <<EOF
System
System
EOF

} >>"${log_file}" 2>&1

# ##############################################################################
# Clean Up #####################################################################
# ##############################################################################
echo "INFO: Cleaning up"

{
    # create output directory
    mkdir -p "2-output"
    cp -np index.ndx "2-output/index.ndx" || exit 1
    cp -np topol_full.top "2-output/topol.top" || exit 1
    cp -np "${sim_name}.gro" "2-output/system.gro" || exit 1
    cp -np "${sim_name}_final.pdb" "2-output/system.pdb" || exit 1

    # copy files with pattern sim_name to simulation directory
    cp -np "${sim_name}."* -t "1-energy-minimization" || exit 1
    cp -np "${sim_name}.gro" -t "0-structure" || exit 1
    rm "${sim_name}."* || true

    # delete all backup files
    find . -type f -name '#*#' -delete || true

    # delete other files that are not needed
    rm -r ./*.mdp ./*.itp index.ndx step*.pdb || true
} >>"${log_file}" 2>&1

echo "Critical: Finished system initialization"
cd "${cwd_initialization}" || exit 1
