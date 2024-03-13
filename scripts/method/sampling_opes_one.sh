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
mdp_file="${mdp_path}/${PRODUCTION_ENSEMBLE,,}_prod_${INTEGRATION_NS}ns.mdp"

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
    echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl"
    echo "Ensemble: ${PRODUCTION_ENSEMBLE} ${TEMPERATURE_K}K ${PRESSURE_BAR}bar"
    echo "################################################################################"
    echo ""

    mapfile -t arr_replica_num < <(seq -f "%02g" 0 "$((ONEOPES_N_REPLICA - 1))")
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
            # small surfaces have smaller cutoffs
            if [[ "${SURFACE_SIZE}" -lt 4 ]]; then
                sed -i 's/^rlist.*/rlist = 0.7/g' "${sim_name}.mdp" || exit 1
                sed -i 's/^rcoulomb.*/rcoulomb = 0.7/g' "${sim_name}.mdp" || exit 1
                sed -i 's/^rvdw.*/rvdw = 0.7/g' "${sim_name}.mdp" || exit 1
            fi
            # non-base replicas write data 10x less frequently
            if [[ "${replica_num}" -ne '00' ]]; then
                sed -i 's/nstxout-compressed.*/nstxout-compressed = 10000/g' "${sim_name}.mdp" || exit 1
                sed -i 's/nstenergy.*/nstenergy = 10000/g' "${sim_name}.mdp" || exit 1
            fi
            # add vacuum parameters to mdp file
            if [[ "${VACUUM_HEIGHT}" -gt 0 ]]; then
                sed -i 's/^ewald-geometry .*/ewald-geometry            = 3dc/g' "${sim_name}.mdp" || exit 1
                sed -i 's/^pbc .*/pbc                       = xy/g' "${sim_name}.mdp" || exit 1
                sed -i 's/^nwall .*/nwall                     = 2/g' "${sim_name}.mdp" || exit 1
            fi

            # copy plumed file
            echo "DEBUG: Copying plumed file"
            dat_file="${dat_path}/plumed.${replica_num}.dat"
            cp "${dat_file}" "plumed.dat"
            sed -i 's/{LOWER_WALL_HEIGHT}/'"${PE_WALL_MIN}"'/g' "plumed.dat" || exit 1
            sed -i 's/{UPPER_WALL_HEIGHT}/'"${PE_WALL_MAX}"'/g' "plumed.dat" || exit 1
            sed -i 's/{WALL_OFFSET}/'"${ATOM_OFFSET}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ONEOPES_LARGE_BARRIER}/'"${ONEOPES_LARGE_BARRIER}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ONEOPES_SMALL_BARRIER}/'"${ONEOPES_SMALL_BARRIER}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ONEOPES_REPLICA_2_TEMP}/'"${ONEOPES_REPLICA_2_TEMP}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ONEOPES_REPLICA_3_TEMP}/'"${ONEOPES_REPLICA_3_TEMP}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ONEOPES_REPLICA_4_TEMP}/'"${ONEOPES_REPLICA_4_TEMP}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ONEOPES_REPLICA_5_TEMP}/'"${ONEOPES_REPLICA_5_TEMP}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ONEOPES_REPLICA_6_TEMP}/'"${ONEOPES_REPLICA_6_TEMP}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ONEOPES_REPLICA_7_TEMP}/'"${ONEOPES_REPLICA_7_TEMP}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ATOM_REFERENCE}/'"${ATOM_REFERENCE}"'/g' "plumed.dat" || exit 1
            if [[ "${N_CALCIUM}" -eq '0' ]]; then
                sed -i 's/NDX_GROUP=Aqueous_Calcium/NDX_GROUP=Crystal_Top_Surface_Calcium/g' "plumed.dat" || exit 1
            fi

            # create tpr file
            echo "DEBUG: Creating tpr file"
            "${GMX_BIN}" -nocopyright grompp \
                -f "${sim_name}.mdp" \
                -c "${previous_sim_name}.gro" \
                -r "${previous_sim_name}.gro" \
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
    echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl"
    echo "Ensemble: ${PRODUCTION_ENSEMBLE} ${TEMPERATURE_K}K ${PRESSURE_BAR}bar"
    echo "################################################################################"
    echo ""
    echo "DEBUG: Requested walltime [hours]: ${WALLTIME_HOURS}"
    echo "DEBUG: Number of MPI processes: ${ONEOPES_N_REPLICA}"
    echo "DEBUG: Number of MPI processes per node: ${ONEOPES_N_SIM_PER_NODE}"
    echo "DEBUG: Number of threads per MPI process: ${ONEOPES_N_THREAD_PER_SIM}"
    echo "DEBUG: Using $((ONEOPES_N_SIM_PER_NODE * ONEOPES_N_THREAD_PER_SIM)) threads per node"
} >>"${log_file_md}" 2>&1

echo "DEBUG: Requested walltime [hours]: ${WALLTIME_HOURS}"
echo "DEBUG: Number of MPI processes: ${ONEOPES_N_REPLICA}"
echo "DEBUG: Number of MPI processes per node: ${ONEOPES_N_SIM_PER_NODE}"
echo "DEBUG: Number of threads per MPI process: ${ONEOPES_N_THREAD_PER_SIM}"
echo "DEBUG: Using $((ONEOPES_N_SIM_PER_NODE * ONEOPES_N_THREAD_PER_SIM)) threads per node"

if [[ -f "${cwd}/completed.txt" ]]; then
    echo "WARNING: completed.txt already exists"
    echo "INFO: Skipping production OneOPES simulation"

elif [[ "${FLAG_ARCHIVE}" = true ]]; then
    echo "WARNING: Archive flag is set, mdrun will not be called"
    echo "INFO: Skipping production OneOPES simulation"

else
    # call mdrun
    echo "INFO: Calling mdrun"
    {
        "${MPI_BIN}" -np "${ONEOPES_N_REPLICA}" \
            --map-by "ppr:${ONEOPES_N_SIM_PER_NODE}:node:PE=${ONEOPES_N_THREAD_PER_SIM}" \
            --use-hwthread-cpus --bind-to 'hwthread' \
            "${GMX_BIN}" -nocopyright mdrun -v \
            -maxh "${WALLTIME_HOURS}" -pin 'on' -noappend \
            -multidir 'replica_'* -deffnm "${sim_name}" -cpi "${sim_name}.cpt" -plumed 'plumed.dat' \
            -hrex -replex "${ONEOPES_N_STEPS}"

        # make completed simulation text file
        if [[ -f "${sim_name}.gro" ]]; then
            echo "DEBUG: Simulation completed"
            touch "${cwd}/completed.txt"
            echo "completed: $(date)" >"${cwd}/completed.txt"
        else
            echo "INFO: Simulation did not complete"
            exit 0
        fi
    } >>"${log_file_md}" 2>&1

    # check if gromacs simulation completed or was terminated
    echo "INFO: Checking if simulation completed successfully"
    bool_completed=false
    while IFS= read -r line; do
        if [[ "${line}" == *"Writing final coordinates."* ]]; then
            bool_completed=true
        fi
    done <"${log_file_md}"
    echo "DEBUG: bool_completed = ${bool_completed}"

    # make completed simulation text file if simulation completed successfully
    if [[ "${bool_completed}" = true ]]; then
        echo "INFO: Simulation completed successfully"
        touch "completed.txt"
        echo "completed: $(date)" >"completed.txt"

    # otherwise, exit script without error
    else
        echo "WARNING: ${sim_name}.gro does not exist. Simulation did not complete successfully"
        echo "INFO: Exiting script"
        exit 0

    fi
fi

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
    echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl"
    echo "Ensemble: ${PRODUCTION_ENSEMBLE} ${TEMPERATURE_K}K ${PRESSURE_BAR}bar"
    echo "################################################################################"
    echo ""
} >>"${log_file_concat}" 2>&1

# rsync output files to archive directory
archive_dir="1-runs"
if [[ ! -d "${archive_dir}" ]] || [[ "${FLAG_ARCHIVE}" = true ]]; then
    echo "INFO: Archiving simulation for replica_00"
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
else
    echo "INFO: Archive directory for replica_00 already exists. Skipping"
fi

# concatenate files into single trajectory
echo "INFO: Concatenating files"
concat_dir="2-concatenated"
if [[ ! -d "${concat_dir}" ]] || [[ "${FLAG_ARCHIVE}" = true ]]; then
    echo "INFO: Concatenating files"
    {
        mkdir -p "${concat_dir}"

        # concatenate xtc files
        "${GMX_BIN}" -nocopyright trjcat \
            -f "${archive_dir}/${sim_name}."*.xtc \
            -o "${concat_dir}/${sim_name}.xtc" || exit 1

        # concatenate edr files
        "${GMX_BIN}" -nocopyright eneconv \
            -f "${archive_dir}/${sim_name}."*.edr \
            -o "${concat_dir}/${sim_name}.edr" || exit 1

        # copy other files
        cp "${archive_dir}/${sim_name}.tpr" "${concat_dir}/${sim_name}.tpr" || exit 1

        # dump pdb file from last frame
        "${GMX_BIN}" -nocopyright trjconv \
            -f "${concat_dir}/${sim_name}.xtc" \
            -s "${concat_dir}/${sim_name}.tpr" \
            -o "${concat_dir}/${sim_name}.pdb" \
            -pbc 'mol' -ur 'compact' -conect \
            -dump "1000000000000" <<EOF
System
EOF

        # dump gro file from last frame
        "${GMX_BIN}" -nocopyright trjconv \
            -f "${concat_dir}/${sim_name}.xtc" \
            -s "${concat_dir}/${sim_name}.tpr" \
            -o "${concat_dir}/${sim_name}.gro" \
            -dump "1000000000000" <<EOF
System
EOF

        # copy plumed files
        cp "${archive_dir}/"*.data "${concat_dir}/" || exit 1
    } >>"${log_file_concat}" 2>&1
else
    echo "INFO: Concatenated directory already exists. Skipping"
fi

# dump trajectory without solvent
echo "INFO: Dumping trajectory without solvent"
nosol_dir="3-no-solvent"
if [[ ! -d "${nosol_dir}" ]] || [[ "${FLAG_ARCHIVE}" = true ]]; then
    echo "INFO: Dumping trajectory without solvent"
    {
        mkdir -p "${nosol_dir}"

        # pdb structure
        "${GMX_BIN}" trjconv \
            -f "${concat_dir}/${sim_name}.xtc" \
            -s "${concat_dir}/${sim_name}.tpr" \
            -o "${nosol_dir}/${sim_name}.pdb" \
            -pbc 'mol' -ur 'compact' -conect \
            -dump "1000000000000" <<EOF
non-Water
EOF

        # xtc trajectory
        "${GMX_BIN}" trjconv \
            -f "${concat_dir}/${sim_name}.xtc" \
            -s "${concat_dir}/${sim_name}.tpr" \
            -o "${nosol_dir}/${sim_name}.xtc" \
            -pbc 'mol' -ur 'compact' <<EOF
non-Water
EOF

        # copy *.data files
        cp "${concat_dir}/"*.data -t "${nosol_dir}/" || exit 1
    } >>"${log_file_concat}" 2>&1
else
    echo "INFO: No-solvent directory already exists. Skipping"
fi

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
    echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl"
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
