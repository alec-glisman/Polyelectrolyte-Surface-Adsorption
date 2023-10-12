#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2024-10-10
# Usage      : ./sampling_hremd.sh
# Notes      : Script assumes that global variables have been set in a
#             submission/input/*.sh script. Script should only be called from
#             the main run.sh script after hremd equilibration has completed.

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
dat_path="${project_path}/parameters/plumed"

if [[ "${FLAG_SAMPLING_OPES_EXPLORE}" = true ]]; then
    echo "CRITICAL: OPES explore + HREMD sampling"
    sample_tag="hremd-opes-explore"
    dat_file="${dat_path}/opes-explore/plumed.dat"
else
    echo "CRITICAL: HREMD sampling"
    sample_tag="hremd"
    dat_file="${dat_path}/harmonic/plumed.dat"
fi

# initial time with _ as separator
time_init="$(date +%Y_%m_%d_%H_%M_%S)"

# Output files
cwd_init="$(pwd)"
cwd="${cwd_init}/3-sampling-${sample_tag}"
log_dir="${cwd}/logs"

# HREMD parameters
mapfile -t arr_replica < <(seq -f "%02g" 0 "$((HREMD_N_REPLICA - 1))")

# #######################################################################################
# Check for existing files ##############################################################
# #######################################################################################
echo "CRITICAL: Starting HREMD production"

# move to working directory
mkdir -p "${cwd}"
mkdir -p "${log_dir}"
cd "${cwd}" || exit 1

# #######################################################################################
# Prepare TPR files #####################################################################
# #######################################################################################
echo "INFO: Preparing TPR files"
log_file="${log_dir}/${time_init}-1-preparation.log"
previous_sim_name="eqbm_hremd_scaled"
previous_archive_dir="${cwd_init}/3-equilibration-hremd"
sim_name="prod_hremd_scaled"

if [[ -f "replica_00/${sim_name}.tpr" ]] && [[ "${FLAG_ARCHIVE}" = false ]]; then
    echo "WARNING: replica_00/${sim_name}.tpr already exists"
    echo "INFO: Skipping TPR preparation"

    # iterate over replicas and allow restarting for plumed files
    echo "INFO: Allowing restarts for plumed files"
    for replica in "${arr_replica[@]}"; do
        cd "${cwd}/replica_${replica}" || exit 1
        sed -i 's/#RESTART/RESTART/g' "plumed.dat" || exit 1
    done

elif [[ -f "completed.txt" ]]; then
    echo "WARNING: completed.txt already exists"
    echo "INFO: Skipping TPR preparation"

else
    {
        # write header to log file
        echo "################################################################################"
        echo "Script: ${BASH_SOURCE[0]}"
        echo "Date: $(date)"
        echo "Host: $(hostname)"
        echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl-${TAG_APPEND}"
        echo "Ensemble: ${PRODUCTION_ENSEMBLE} ${TEMPERATURE_K}K ${PRESSURE_BAR}bar"
        echo "################################################################################"
        echo ""

        # iterate over replicas
        for replica in "${arr_replica[@]}"; do
            # create replica directory and move into it
            echo "DEBUG: Initializing replica_${replica}"
            dir_replica="${cwd}/replica_${replica}"
            mkdir -p "${dir_replica}"
            cd "${dir_replica}" || exit 1

            echo "DEBUG: Copying files for replica_${replica}"

            # copy output files from equilibration
            dir_replica_eqbm="${previous_archive_dir}/replica_${replica}/2-output"
            cp -np "${dir_replica_eqbm}/${previous_sim_name}.gro" "${previous_sim_name}.gro" || exit 1
            cp -np "${dir_replica_eqbm}/topol.top" "topol.top" || exit 1
            cp -np "${dir_replica_eqbm}/index.ndx" "index.ndx" || exit 1

            # copy mdp file
            cp "${mdp_file}" "${sim_name}.mdp" || exit 1
            sed -i 's/ref-t.*/ref-t                     = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
            sed -i 's/gen-temp.*/gen-temp                  = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
            sed -i 's/ref-p.*/ref-p                     = '"${PRESSURE_BAR} ${PRESSURE_BAR}/g" "${sim_name}.mdp" || exit 1

            # copy plumed file
            cp "${dat_file}" "plumed.dat" || exit 1
            sed -i 's/{LOWER_WALL_HEIGHT}/'"${PE_WALL_MIN}"'/g' "plumed.dat" || exit 1
            sed -i 's/{UPPER_WALL_HEIGHT}/'"${PE_WALL_MAX_EQBM}"'/g' "plumed.dat" || exit 1
            sed -i 's/{WALL_OFFSET}/'"${ATOM_OFFSET}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ATOM_REFERENCE}/'"${ATOM_REFERENCE}"'/g' "plumed.dat" || exit 1
            if [[ "${N_CALCIUM}" -eq '0' ]]; then
                sed -i 's/NDX_GROUP=Aqueous_Calcium/NDX_GROUP=Aqueous_Sodium/g' "plumed.dat" || exit 1
            fi

            # create tpr file
            echo "DEBUG: Creating TPR file for replica_${replica}"
            "${GMX_BIN}" -nocopyright grompp \
                -f "${sim_name}.mdp" \
                -c "${previous_sim_name}.gro" \
                -n "index.ndx" \
                -p "topol.top" \
                -o "${sim_name}.tpr"

            # archive files that are no longer needed
            echo "DEBUG: Archiving files for replica_${replica}"
            dir_input="1-input"
            mkdir -p "${dir_input}"
            mv "${sim_name}.mdp" "${dir_input}" || exit 1
            cp "plumed.dat" "mdout.mdp" "topol.top" "index.ndx" -t "${dir_input}" || exit 1

            # delete files
            rm "${previous_sim_name}.gro" || exit 1
            rm 'mdout.mdp' || exit 1

        done

        echo "INFO: All replicas prepared successfully"
    } >>"${log_file}" 2>&1
fi

# #######################################################################################
# Run simulation ########################################################################
# #######################################################################################
echo "INFO: Running production HREMD simulation"
log_file="${log_dir}/${time_init}-2-mdrun.log"

if [[ -f "completed.txt" ]]; then
    echo "WARNING: completed.txt already exists"
    echo "INFO: Skipping production HREMD simulation"

elif [[ "${FLAG_ARCHIVE}" = true ]]; then
    echo "WARNING: Archive flag is set, mdrun will not be called"
    echo "INFO: Skipping production HREMD simulation"

else
    {
        # write header to log file
        echo "################################################################################"
        echo "Script: ${BASH_SOURCE[0]}"
        echo "Date: $(date)"
        echo "Host: $(hostname)"
        echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl-${TAG_APPEND}"
        echo "Ensemble: ${PRODUCTION_ENSEMBLE} ${TEMPERATURE_K}K ${PRESSURE_BAR}bar"
        echo "################################################################################"
        echo ""

        cd "${cwd}" || exit 1
        sleep '10s' # wait for file system to catch up

        echo "INFO: Calling mdrun"
        "${MPI_BIN}" -np "${HREMD_N_REPLICA}" \
            --map-by "ppr:${HREMD_N_SIM_PER_NODE}:node:PE=${HREMD_N_THREAD_PER_SIM}" \
            --use-hwthread-cpus --bind-to 'hwthread' \
            "${GMX_BIN}" -nocopyright mdrun -v \
            -maxh "${WALLTIME_HOURS}" -pin 'on' -noappend \
            -multidir 'replica_'* -deffnm "${sim_name}" -cpi "${sim_name}.cpt" -plumed "plumed.dat" \
            -hrex -replex "${HREMD_N_STEPS}"

        sleep '10s' # wait for file system to catch up
    } >>"${log_file}" 2>&1

    # check if gromacs simulation completed or was terminated
    echo "INFO: Checking if simulation completed successfully"
    bool_completed=false
    while IFS= read -r line; do
        if [[ "${line}" == *"Writing final coordinates."* ]]; then
            bool_completed=true
        fi
    done <"${log_file}"
    echo "DEBUG: bool_completed = ${bool_completed}"

    {
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
    } >>"${log_file}" 2>&1
fi

# #######################################################################################
# Clean Up ##############################################################################
# #######################################################################################
echo "INFO: Cleaning up"
log_file="${log_dir}/${time_init}-3-cleanup.log"
archive_sdir="2-output"

if [[ -f "completed.txt" ]]; then
    {
        # write header to log file
        echo "################################################################################"
        echo "Script: ${BASH_SOURCE[0]}"
        echo "Date: $(date)"
        echo "Host: $(hostname)"
        echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl-${TAG_APPEND}"
        echo "Ensemble: ${PRODUCTION_ENSEMBLE} ${TEMPERATURE_K}K ${PRESSURE_BAR}bar"
        echo "################################################################################"
        echo ""

        for replica in "${arr_replica[@]}"; do
            # move to replica directory
            dir_replica="${cwd}/replica_${replica}"
            cd "${dir_replica}" || exit 1
            echo "DEBUG: Moving to replica ${replica}"

            # delete backup files
            rm -r "./#"* || true
            rm -r "./bck."* || true

            # copy and then delete output files if output directory does not exist
            if [[ ! -d "${archive_sdir}" ]]; then
                echo "DEBUG: Archiving simulation for replica_${replica}"
                mkdir -p "${archive_sdir}"
                rsync --archive --verbose --progress --human-readable --itemize-changes \
                    "${sim_name}."* "${archive_sdir}/" || exit 1
                cp -np 'index.ndx' 'topol.top' ./*.dat ./*.data -t "${archive_sdir}" || exit 1
                rm "./${sim_name}."* || exit 1
                rm 'index.ndx' 'topol.top' ./*.dat ./*.data || exit 1
            else
                echo "WARNING: ${archive_sdir} already exists"
                echo "INFO: Skipping archiving simulation for replica_${replica}"
            fi

        done

        echo "INFO: All replicas cleaned successfully"
    } >>"${log_file}" 2>&1

else
    echo "WARNING: completed.txt does not exist"
    echo "INFO: Skipping cleanup"
fi

# #######################################################################################
# Concatenate trajectories for replica_00 ###############################################
# #######################################################################################
echo "INFO: Archiving simulation for replica_00"
log_file="${log_dir}/${time_init}-4-concatenation.log"
cd "${cwd}/replica_00" || exit 1

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
} >>"${log_file}" 2>&1

# concatenate files into single trajectory
echo "INFO: Concatenating trajectories"
archive_dir="${archive_sdir}"
concat_dir="3-concatenated"
{
    mkdir -p "${concat_dir}"

    # concatenate xtc files if output file does not exist
    if [[ ! -f "${concat_dir}/${sim_name}.xtc" ]]; then
        "${GMX_BIN}" -quiet trjcat \
            -f "${archive_dir}/${sim_name}."*.xtc \
            -o "${concat_dir}/${sim_name}.xtc"
    else
        echo "WARNING: ${concat_dir}/${sim_name}.xtc already exists"
        echo "INFO: Skipping concatenation of xtc files"
    fi

    # concatenate edr files if output file does not exist
    if [[ ! -f "${concat_dir}/${sim_name}.edr" ]]; then
        "${GMX_BIN}" -quiet eneconv \
            -f "${archive_dir}/${sim_name}."*.edr \
            -o "${concat_dir}/${sim_name}.edr"
    else
        echo "WARNING: ${concat_dir}/${sim_name}.edr already exists"
        echo "INFO: Skipping concatenation of edr files"
    fi

    # copy main structure file
    cp -pn "${archive_dir}/${sim_name}.tpr" "${concat_dir}/${sim_name}.tpr"

    # pdb structure if output file does not exist
    if [[ ! -f "${concat_dir}/${sim_name}.pdb" ]]; then
        "${GMX_BIN}" -quiet trjconv \
            -f "${concat_dir}/${sim_name}.xtc" \
            -s "${concat_dir}/${sim_name}.tpr" \
            -o "${concat_dir}/${sim_name}.pdb" \
            -conect \
            -dump "1000000000000" <<EOF
System
EOF
    else
        echo "WARNING: ${concat_dir}/${sim_name}.pdb already exists"
        echo "INFO: Skipping dumping of pdb structure"
    fi

    # gro structure if output file does not exist
    if [[ ! -f "${concat_dir}/${sim_name}.gro" ]]; then
        "${GMX_BIN}" -quiet trjconv \
            -f "${concat_dir}/${sim_name}.xtc" \
            -s "${concat_dir}/${sim_name}.tpr" \
            -o "${concat_dir}/${sim_name}.gro" \
            -dump "1000000000000" <<EOF
System
EOF

    else
        echo "WARNING: ${concat_dir}/${sim_name}.gro already exists"
        echo "INFO: Skipping dumping of pdb structure"
    fi

    # delete backup files
    rm -r "${concat_dir}/#"* || true
} >>"${log_file}" 2>&1

# dump trajectory without solvent
echo "INFO: Dumping trajectory without solvent"
nosol_dir="4-no-solvent"
{
    mkdir -p "${nosol_dir}"

    # pdb structure if output file does not exist
    if [[ ! -f "${nosol_dir}/${sim_name}_no_sol.pdb" ]]; then
        "${GMX_BIN}" -quiet trjconv \
            -f "${concat_dir}/${sim_name}.xtc" \
            -s "${concat_dir}/${sim_name}.tpr" \
            -o "${nosol_dir}/${sim_name}_no_sol.pdb" \
            -pbc 'mol' -ur 'compact' -conect \
            -dump "1000000000000" <<EOF
non-Water
EOF
    else
        echo "WARNING: ${nosol_dir}/${sim_name}_no_sol.pdb already exists"
        echo "INFO: Skipping dumping of pdb structure"
    fi

    # xtc trajectory if output file does not exist
    if [[ ! -f "${nosol_dir}/${sim_name}_no_sol.xtc" ]]; then
        "${GMX_BIN}" -quiet trjconv \
            -f "${concat_dir}/${sim_name}.xtc" \
            -s "${concat_dir}/${sim_name}.tpr" \
            -o "${nosol_dir}/${sim_name}_no_sol.xtc" \
            -pbc 'mol' -ur 'compact' <<EOF
non-Water
EOF
    else
        echo "WARNING: ${nosol_dir}/${sim_name}_no_sol.xtc already exists"
        echo "INFO: Skipping dumping of xtc trajectory"
    fi

    # delete backup files
    rm -r "${nosol_dir}/#"* || true

    echo "INFO: replica_00 archived successfully"
} >>"${log_file}" 2>&1

# #######################################################################################
# Completed #############################################################################
# #######################################################################################

# move to initial working directory
cd "${cwd_init}" || exit 1
echo "CRITICAL: Finished HREMD production"
