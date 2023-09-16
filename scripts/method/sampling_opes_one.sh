#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-09-12
# Usage      : ./sampling_opes_explore.sh
# Notes      : Script assumes that global variables have been set in a
#             submission/input/*.sh script. Script should only be called from
#             the main run.sh script after initialization is complete.

# built-in shell options
set -o errexit  # exit when a command fails. Add || true to commands allowed to fail
set -o nounset  # exit when script tries to use undeclared variables
set -o pipefail # exit when a command in a pipe fails

# #######################################################################################
# Default Preferences ###################################################################
# #######################################################################################
echo "INFO: Setting default preferences"

# find path to this script
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
project_path="${script_path}/../.."

# Gromacs files
mdp_path="${project_path}/parameters/mdp/molecular-dynamics"
mdp_file="${mdp_path}/${PRODUCTION_ENSEMBLE,,}_prod.mdp"

# Plumed files
dat_path="${project_path}/parameters/plumed/opes-one"

# initial time with _ as separator
time_init="$(date +%Y_%m_%d_%H_%M_%S)"

# Output files
cwd_init="$(pwd)"
cwd="${cwd_init}/3-sampling-opes-one"
log_dir="${cwd}/logs"
log_file_prep="${log_dir}/${time_init}-0-prep.log"
log_file_md="${log_dir}/${time_init}-1-md.log"
log_file_concat="${log_dir}/${time_init}-2-concatenation.log"
log_file_cleanup="${log_dir}/${time_init}-3-cleanup.log"

# move to working directory
mkdir -p "${cwd}"
cd "${cwd}" || exit
mkdir -p "${log_dir}"
echo "CRITICAL: Starting OneOPES production"

# #######################################################################################
# Create replica dirs and copy files ####################################################
# #######################################################################################
echo "INFO: Creating replica dirs and copying input files"
previous_sim_name="prod_eqbm"
previous_archive_dir="${cwd_init}/2-equilibration/4-output"
sim_name="prod_opes_one_multicv"

{
    # header
    echo "################################################################################"
    echo "Script: ${BASH_SOURCE[0]}"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl-${TAG_APPEND}"
    echo "Ensemble: ${PRODUCTION_ENSEMBLE} ${TEMPERATURE_K}K ${PRESSURE_BAR}bar"
    echo "################################################################################"
    echo ""

    mapfile -t arr_replica_num < <(seq -f "%02g" 0 "$((N_REPLICA - 1))")
    echo "Replica index array: ${arr_replica_num[*]}"

    for replica_num in "${arr_replica_num[@]}"; do
        replica_dir="${cwd}/replica_${replica_num}"
        echo "DEBUG: replica_dir: ${replica_dir}"

        # if directory does not exist, create it and copy equilibration files
        if [[ ! -d "${replica_dir}" ]]; then
            echo "DEBUG: Creating replica directory"
            mkdir -p "${replica_dir}"
            cp -np "${previous_archive_dir}/${previous_sim_name}.gro" "${replica_dir}/${previous_sim_name}.gro"
            cp -np "${previous_archive_dir}/topol.top" "${replica_dir}/topol.top"
            cp -np "${previous_archive_dir}/index.ndx" "${replica_dir}/index.ndx"
        else
            echo "DEBUG: Replica directory already exists"
        fi
        cd "${replica_dir}" || exit

        # if tpr file does not exist, create it
        if [[ ! -f "${replica_dir}/${sim_name}.tpr" ]]; then

            # copy mdp file
            echo "DEBUG: Copying mdp file"
            cp "${mdp_file}" "${replica_dir}/${sim_name}.mdp"
            sed -i 's/ref-t.*/ref-t                     = '"${TEMPERATURE_K}/g" "${replica_dir}/${sim_name}.mdp"
            sed -i 's/gen-temp.*/gen-temp                  = '"${TEMPERATURE_K}/g" "${replica_dir}/${sim_name}.mdp"
            sed -i 's/ref-p.*/ref-p                     = '"${PRESSURE_BAR} ${PRESSURE_BAR}/g" "${replica_dir}/${sim_name}.mdp"

            # copy plumed file
            echo "DEBUG: Copying plumed file"
            dat_file="${dat_path}/plumed.${replica_num}.dat"
            cp "${dat_file}" "${replica_dir}/plumed.dat"
            sed -i 's/{LOWER_WALL_HEIGHT}/'"${PE_WALL_MIN}"'/g' "plumed.dat" || exit 1
            sed -i 's/{UPPER_WALL_HEIGHT}/'"${PE_WALL_MAX}"'/g' "plumed.dat" || exit 1
            sed -i 's/{WALL_OFFSET}/'"${ATOM_OFFSET}"'/g' "${replica_dir}/plumed.dat"
            sed -i 's/{ATOM_REFERENCE}/'"${ATOM_REFERENCE}"'/g' "${replica_dir}/plumed.dat"
            if [[ "${N_CALCIUM}" -eq '0' ]]; then
                sed -i 's/NDX_GROUP=Aqueous_Calcium/NDX_GROUP=Aqueous_Sodium/g' "plumed.dat"
            fi

            # create tpr file
            echo "DEBUG: Creating tpr file"
            "${GMX_BIN}" -quiet -nocopyright grompp \
                -f "${sim_name}.mdp" \
                -c "${previous_sim_name}.gro" \
                -n "index.ndx" \
                -p "topol.top" \
                -o "${sim_name}.tpr"
            rm "${previous_sim_name}.gro"

        else
            echo "DEBUG: Using existing tpr file"

            # activate restart in plumed file
            sed -i 's/#RESTART/RESTART/g' "plumed.dat"
        fi

    done

} >>"${log_file_prep}" 2>&1

# #######################################################################################
# Run simulation ########################################################################
# #######################################################################################
echo "INFO: Running production OneOPES"
cd "${cwd}" || exit

# print information to log and console
{
    echo "################################################################################"
    echo "Script: ${BASH_SOURCE[0]}"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl-${TAG_APPEND}"
    echo "Ensemble: ${PRODUCTION_ENSEMBLE} ${TEMPERATURE_K}K ${PRESSURE_BAR}bar"
    echo "################################################################################"
    echo ""
    echo "DEBUG: Requested walltime [hours]: ${WALLTIME_HOURS}"
    echo "DEBUG: Number of MPI processes: ${N_REPLICA}"
    echo "DEBUG: Number of MPI processes per node: ${N_SIM_PER_NODE}"
    echo "DEBUG: Number of threads per MPI process: ${N_THREAD_PER_SIM}"
    echo "DEBUG: Using $((N_SIM_PER_NODE * N_THREAD_PER_SIM)) threads per node"
} >>"${log_file_md}" 2>&1

echo "DEBUG: Requested walltime [hours]: ${WALLTIME_HOURS}"
echo "DEBUG: Number of MPI processes: ${N_REPLICA}"
echo "DEBUG: Number of MPI processes per node: ${N_SIM_PER_NODE}"
echo "DEBUG: Number of threads per MPI process: ${N_THREAD_PER_SIM}"
echo "DEBUG: Using $((N_SIM_PER_NODE * N_THREAD_PER_SIM)) threads per node"

{
    if [[ -f "${cwd}/completed.txt" ]]; then
        echo "WARNING: completed.txt already exists"
        echo "INFO: Skipping production OneOPES simulation"

    elif [[ "${FLAG_ARCHIVE}" = true ]]; then
        echo "WARNING: Archive flag is set, mdrun will not be called"
        echo "INFO: Skipping production OneOPES simulation"

    else
        # call mdrun
        "${MPI_BIN}" -np "${N_REPLICA}" \
            --use-hwthread-cpus --bind-to 'hwthread' --report-bindings \
            --map-by "ppr:${N_SIM_PER_NODE}:node:PE=${N_THREAD_PER_SIM}" \
            "${GMX_BIN}" -quiet -nocopyright mdrun -v \
            -maxh "${WALLTIME_HOURS}" \
            -multidir 'replica_'* \
            -deffnm "${sim_name}" -cpi "${sim_name}.cpt" \
            -pin on -pinoffset "${PIN_OFFSET}" -pinstride 1 -ntomp "${CPU_THREADS}" \
            -gpu_id "${GPU_IDS}" \
            -plumed "plumed.dat" \
            -hrex -replex "${N_STEPS_HREX}" \
            -noappend

        # make completed simulation text file
        if [[ -f "${sim_name}.gro" ]]; then
            echo "DEBUG: Simulation completed"
            touch "${cwd}/completed.txt"
            echo "completed: $(date)" >"${cwd}/completed.txt"
        fi
    fi
} >>"${log_file_md}" 2>&1

# #######################################################################################
# Concatenate trajectories ##############################################################
# #######################################################################################
cd "${cwd}/replica_00" || exit

# write header to log file
{
    echo "################################################################################"
    echo "Script: ${BASH_SOURCE[0]}"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl-${TAG_APPEND}"
    echo "Ensemble: ${PRODUCTION_ENSEMBLE} ${TEMPERATURE_K}K ${PRESSURE_BAR}bar"
    echo "################################################################################"
    echo ""
} >>"${log_file_concat}" 2>&1

# rsync output files to archive directory
echo "INFO: Archiving simulation for replica_00"
archive_dir="1-runs"
{
    rsync --archive --verbose --progress --human-readable --itemize-changes \
        "${sim_name}."* "${archive_dir}/"
    rsync --archive --verbose --progress --human-readable --itemize-changes \
        ./*.data "${archive_dir}/"
    rsync --archive --verbose --progress --human-readable --itemize-changes \
        ./*.dat "${archive_dir}/"
    rsync --archive --verbose --progress --human-readable --itemize-changes \
        ./*.Kernels* "${archive_dir}/"
} >>"${log_file_concat}" 2>&1

# concatenate files into single trajectory
echo "INFO: Concatenating files"
concat_dir="2-concatenated"
{
    mkdir -p "${concat_dir}"

    # concatenate xtc files
    "${GMX_BIN}" -quiet -nocopyright trjcat \
        -f "${archive_dir}/${sim_name}."*.xtc \
        -o "${concat_dir}/${sim_name}.xtc" || exit 1

    # concatenate edr files
    "${GMX_BIN}" -quiet -nocopyright eneconv \
        -f "${archive_dir}/${sim_name}."*.edr \
        -o "${concat_dir}/${sim_name}.edr" || exit 1

    # copy other files
    cp "${archive_dir}/${sim_name}.tpr" "${concat_dir}/${sim_name}.tpr" || exit 1

    # dump pdb file from last frame
    "${GMX_BIN}" -quiet -nocopyright trjconv \
        -f "${concat_dir}/${sim_name}.xtc" \
        -s "${concat_dir}/${sim_name}.tpr" \
        -o "${concat_dir}/${sim_name}.pdb" \
        -pbc 'mol' -ur 'compact' -conect \
        -dump "1000000000000" <<EOF
System
EOF

    # dump gro file from last frame
    "${GMX_BIN}" -quiet -nocopyright trjconv \
        -f "${concat_dir}/${sim_name}.xtc" \
        -s "${concat_dir}/${sim_name}.tpr" \
        -o "${concat_dir}/${sim_name}.gro" \
        -dump "1000000000000" <<EOF
System
EOF

    # copy plumed files
    cp "${archive_dir}/"*.data "${concat_dir}/" || exit 1
} >>"${log_file_concat}" 2>&1

# dump trajectory without solvent
echo "INFO: Dumping trajectory without solvent"
nosol_dir="3-no-solvent"
{
    mkdir -p "${nosol_dir}"

    # pdb structure
    "${GMX_BIN}" -quiet trjconv \
        -f "${concat_dir}/${sim_name}.xtc" \
        -s "${concat_dir}/${sim_name}.tpr" \
        -o "${nosol_dir}/${sim_name}.pdb" \
        -pbc 'mol' -ur 'compact' -conect \
        -dump "1000000000000" <<EOF
non-Water
EOF

    # xtc trajectory
    "${GMX_BIN}" -quiet trjconv \
        -f "${concat_dir}/${sim_name}.xtc" \
        -s "${concat_dir}/${sim_name}.tpr" \
        -o "${nosol_dir}/${sim_name}.xtc" \
        -pbc 'mol' -ur 'compact' <<EOF
non-Water
EOF

    # copy *.data files
    cp "${concat_dir}/"*.data -t "${nosol_dir}/" || exit 1
} >>"${log_file_concat}" 2>&1

# #######################################################################################
# Clean Up ##############################################################################
# #######################################################################################
echo "INFO: Cleaning up"

# write header to log file
{
    echo "################################################################################"
    echo "Script: ${BASH_SOURCE[0]}"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl-${TAG_APPEND}"
    echo "Ensemble: ${PRODUCTION_ENSEMBLE} ${TEMPERATURE_K}K ${PRESSURE_BAR}bar"
    echo "################################################################################"
    echo ""
} >>"${log_file_cleanup}" 2>&1

{
    # iterate over directories and delete backup files
    for dir in "${archive_dir}" "${concat_dir}" "${nosol_dir}" "."; do
        find "${dir}" -type f -name '#*#' -delete || true
    done

    # move to initial working directory
    cd "${cwd_init}" || exit 1
} >>"${log_file_cleanup}" 2>&1

echo "CRITICAL: Finished OneOPES production"
