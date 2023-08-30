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

# Default Preferences ###################################################################
echo "INFO: Setting default preferences"

# find path to this script
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
project_path="${script_path}/../.."
structure_path="${project_path}/initial-structure"

# Gromacs files
mdp_file="${project_path}/parameters/mdp/energy-minimization/em.mdp"

# Default structure files
pdb_carbonate="${structure_path}/polyatomic-ions/carbonate_ion.pdb"
gro_water="spc216.gro"

# Output files
cwd_initialization="$(pwd)"
cwd="$(pwd)/1-energy-minimization"
sim_name="energy_minimization"
log_file="system_initialization.log"

# Check for existing files #############################################################
echo "CRITICAL: Starting system initialization"

# move to working directory
mkdir -p "${cwd}"
cd "${cwd}" || exit

# see if "2-output/system.gro" exists
if [[ -f "2-output/system.gro" ]]; then
    echo "WARNING: 2-output/system.gro already exists"
    echo "INFO: Exiting script"
    exit 0
fi

# Copy input files to working directory ################################################
echo "INFO: Copying input files to working directory"

{
    # copy force field files
    mkdir -p "forcefield.ff"
    cp -rp "${FF_DIR}/"* -t "forcefield.ff" || exit 1

    # copy files
    # if any cp commands failed, exit script
    cp -p "${mdp_file}" "mdin.mdp" || exit 1
    cp -p "${PDB_CRYSTAL}" "crystal.pdb" || exit 1
    cp -p "${PDB_CHAIN}" "chain.pdb" || exit 1

} >>"${log_file}" 2>&1

# Import Structure to Gromacs ##########################################################
echo "INFO: Importing structure to Gromacs"

{
    # insert-molecules to create simulation box of crystal and chains
    if [[ "${N_CHAIN}" -gt 0 ]]; then
        "${GMX_BIN}" -nocopyright -quiet insert-molecules \
            -f "crystal.pdb" \
            -ci "chain.pdb" \
            -o "${sim_name}.pdb" \
            -nmol "${N_CHAIN}" \
            -radius '0.5' \
            -try '1000'
    else
        cp -p "crystal.pdb" "${sim_name}.pdb"
    fi

    # insert-molecules to add carbonate ions
    if [[ "${N_CARBONATE}" -gt 0 ]]; then
        "${GMX_BIN}" -quiet insert-molecules \
            -f "${sim_name}.pdb" \
            -ci "${pdb_carbonate}" \
            -o "${sim_name}.pdb" \
            -nmol "${N_CARBONATE}" \
            -radius '0.5' \
            -try '1000'
    fi

    # convert pdb to gro
    "${GMX_BIN}" -nocopyright -quiet pdb2gmx -v \
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

} >>"${log_file}" 2>&1

echo "DEBUG: Initial box height [A]: ${z}"
echo "DEBUG: Final box height [A]: ${new_z}"

# Add Solvent #########################################################################
echo "INFO: Adding solvent"
{
    # add solvent
    "${GMX_BIN}" -nocopyright -quiet solvate \
        -cp "${sim_name}.gro" \
        -cs "${gro_water}" \
        -o "${sim_name}.gro" \
        -p "topol.top"

    # create index file
    "${GMX_BIN}" -quiet make_ndx \
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
        "${GMX_BIN}" -nocopyright -quiet grompp \
            -f "mdin.mdp" \
            -c "${sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        # add ions
        "${GMX_BIN}" --nocopyright -quiet genion \
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
        "${GMX_BIN}" -nocopyright -quiet grompp \
            -f "mdin.mdp" \
            -c "${sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        # add ions
        "${GMX_BIN}" --nocopyright -quiet genion \
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
        "${GMX_BIN}" -nocopyright -quiet grompp \
            -f "mdin.mdp" \
            -c "${sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        # add ions
        "${GMX_BIN}" --nocopyright -quiet genion \
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
    # remake tpr file and topology file with no imports
    "${GMX_BIN}" -quiet grompp \
        -f "mdin.mdp" \
        -c "${sim_name}.gro" \
        -p "topol.top" \
        -pp "topol_full.top" \
        -o "${sim_name}.tpr" \
        -maxwarn '1'
} >>"${log_file}" 2>&1

# output the number of water molecules
n_water="$(grep -c "SOL" "${sim_name}.gro")"
n_water=$((n_water / 3))
echo "DEBUG: Number of water molecules: ${n_water}"

# grep lines in log file that contain "System has non-zero total charge" and save to array
grep -n "System has non-zero total charge" "${log_file}" >charge_lines.log
mapfile -t charge_lines <charge_lines.log
# print last line in array
last_charge_line="${charge_lines[-1]}"
echo "CRITICAL: ${last_charge_line}"

# Create TPR file ######################################################################
echo "INFO: Archiving files"

{
    # copy input files to structure directory
    mkdir -p '0-structure'
    cp -p 'pdb2gmx_clean.pdb' '0-structure/system.pdb' || exit 1
    cp -p 'topol_full.top' '0-structure/topol.top' || exit 1
    cp -p 'index.ndx' '0-structure/index.ndx' || exit 1
    cp -rp ./*.itp '0-structure/' || exit 1

    # copy simulation files to simulation directory
    mkdir -p '1-energy-minimization'
    cp -p 'mdin.mdp' '1-energy-minimization/mdin.mdp' || exit 1
    cp -p 'mdout.mdp' '1-energy-minimization/mdout.mdp' || exit 1
    cp -p 'index.ndx' '1-energy-minimization/index.ndx' || exit 1
    cp -p 'topol_full.top' '1-energy-minimization/topol.top' || exit 1
    cp -p "${sim_name}.tpr" "1-energy-minimization/${sim_name}.tpr" || exit 1
} >>"${log_file}" 2>&1

# Run Energy Minimization ##############################################################
echo "INFO: Running energy minimization"

{
    # run energy minimization
    "${MPI_BIN}" -np '1' \
        --map-by "ppr:1:node:PE=${CPU_THREADS}" \
        --use-hwthread-cpus --bind-to 'hwthread' \
        "${GMX_BIN}" -quiet -nocopyright mdrun -v \
        -deffnm "${sim_name}" \
        -pin on -pinoffset "${PIN_OFFSET}" -pinstride 1 -ntomp "${CPU_THREADS}" \
        -gpu_id "${GPU_IDS}" || exit 1

    # dump last frame of energy minimization as gro file
    "${GMX_BIN}" -quiet trjconv \
        -f "${sim_name}.trr" \
        -s "${sim_name}.tpr" \
        -o "${sim_name}.gro" \
        -dump '100000' <<EOF
System
EOF

    # dump last frame of energy minimization as pdb file
    "${GMX_BIN}" -quiet -nocopyright trjconv \
        -f "${sim_name}.trr" \
        -s "${sim_name}.tpr" \
        -o "${sim_name}_final.pdb" \
        -pbc 'mol' -ur 'compact' \
        -dump '100000' -conect <<EOF
System
System
EOF

} >>"${log_file}" 2>&1

# Make Index File #####################################################################
echo "INFO: Making index file"

{
    # add crystal groups to index file
    idx_group='17'
    "${GMX_BIN}" -quiet make_ndx \
        -f "crystal.pdb" \
        -n "index.ndx" \
        -o "index.ndx" \
        <<EOF
a *
name ${idx_group} Crystal
a CX* | a OX*
name $((idx_group + 1)) Crystal_Carbonate
a CX*
name $((idx_group + 2)) Crystal_Carbonate_Carbon
a OX*
name $((idx_group + 3)) Crystal_Carbonate_Oxygen
a CA*
name $((idx_group + 4)) Crystal_Calcium

q
EOF
    idx_group=$((idx_group + 5))

    # add chain groups to index file
    if [[ "${N_CHAIN}" -gt 0 ]]; then
        "${GMX_BIN}" -quiet make_ndx \
            -f "${sim_name}_final.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a * & chain B
name ${idx_group} Chain
a O* & chain B
name $((idx_group + 1)) Chain_Oxygen

q
EOF
        idx_group=$((idx_group + 2))
    fi

    # add aqueous sodium ions to index file
    if [[ "${N_SODIUM}" -gt 0 ]]; then
        "${GMX_BIN}" -quiet make_ndx \
            -f "${sim_name}_final.pdb" \
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
        "${GMX_BIN}" -quiet make_ndx \
            -f "${sim_name}_final.pdb" \
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
        "${GMX_BIN}" -quiet make_ndx \
            -f "${sim_name}_final.pdb" \
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
        "${GMX_BIN}" -quiet make_ndx \
            -f "${sim_name}_final.pdb" \
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

# Clean up #############################################################################
echo "INFO: Cleaning up"

{
    # create output directory
    mkdir -p "2-output"
    cp -p index.ndx "2-output/index.ndx" || exit 1
    cp -p topol_full.top "2-output/topol.top" || exit 1
    cp -p "${sim_name}.gro" "2-output/system.gro" || exit 1
    cp -p "${sim_name}_final.pdb" "2-output/system.pdb" || exit 1

    # copy files with pattern sim_name to simulation directory
    cp -p "${sim_name}."* -t "1-energy-minimization" || exit 1
    cp -p "${sim_name}.gro" -t "0-structure" || exit 1
    rm "${sim_name}."* || true

    # delete all backup files
    find . -type f -name '#*#' -delete || true

    # delete other files that are not needed
    rm -r ./*.mdp ./*.itp index.ndx step*.pdb || true
} >>"${log_file}" 2>&1

echo "Critical: Finished system initialization"
cd "${cwd_initialization}" || exit 1
