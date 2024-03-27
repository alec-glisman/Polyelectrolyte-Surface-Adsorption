#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2024-10-03
# Usage      : ./equilibration_hremd.sh
# Notes      : Script assumes that global variables have been set in a
#             submission/input/*.sh script. Script should only be called from
#             the main run.sh script after main equilibration has been completed.

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
mdp_file="${mdp_path}/${PRODUCTION_ENSEMBLE,,}_eqbm.mdp"

# Plumed files
dat_path="${project_path}/parameters/plumed"
dat_file="${dat_path}/harmonic/plumed.dat"

# initial time with _ as separator
time_init="$(date +%Y_%m_%d_%H_%M_%S)"

# Output files
cwd_init="$(pwd)"
cwd="${cwd_init}/3-equilibration-hremd"
log_dir="${cwd}/logs"

# atoms to bias with HREMD
bias_atoms=(
    # synthetic polymer
    'C' 'C3' 'H1' 'HC' 'HO' 'O' 'OC' 'OH' 'OS'
    # biological polymer
    'H' 'H1' 'HC' 'HO' 'HP' 'C' 'CT' 'O' 'O2' 'OH' 'N' 'N3'
    # aqueous counterions
    'Na'
)

# HREMD parameters
mapfile -t arr_replica < <(seq -f "%02g" 0 "$((HREMD_N_REPLICA - 1))")
mapfile -t arr_temp < <(
    awk -v n="${HREMD_N_REPLICA}" \
        -v t_min="${TEMPERATURE_K}" \
        -v t_max='440' \
        -v PREC='100' \
        'BEGIN{for(i=0; i < n; i++){
        printf "%.17g\n", t_min*exp(i*log(t_max/t_min)/(n-1));
    }}'
)
arr_lambda=()
for ((i = 0; i < HREMD_N_REPLICA; i++)); do
    # shellcheck disable=SC2207
    arr_lambda+=($(bc -l <<<"scale=16; ${TEMPERATURE_K}/${arr_temp[i]}" | awk '{printf "%.17g\n", $0}'))
done

# #######################################################################################
# Check for existing files ##############################################################
# #######################################################################################
echo "CRITICAL: Starting HREMD equilibration"

# move to working directory
mkdir -p "${cwd}"
mkdir -p "${log_dir}"
cd "${cwd}" || exit 1

# check if output gro file already exists
if [[ -f "replica_00/2-output/eqbm_hremd_scaled.gro" ]]; then
    echo "WARNING: replica_00/2-output/eqbm_hremd_scaled.gro already exists"
    echo "INFO: Exiting script"
    exit 0
fi

# #######################################################################################
# Prepare TPR files #####################################################################
# #######################################################################################
echo "INFO: Preparing TPR files"
log_file="${log_dir}/${time_init}-1-preparation.log"
previous_sim_name="prod_eqbm"
previous_archive_dir="${cwd_init}/2-equilibration/4-output"
sim_name="eqbm_hremd_scaled"

if [[ -f "replica_00/${sim_name}.tpr" ]]; then
    echo "WARNING: replica_00/${sim_name}.tpr already exists"
    echo "INFO: Skipping TPR preparation"

    # iterate over replicas and allow restarting for plumed files
    echo "INFO: Allowing restarts for plumed files"
    for replica in "${arr_replica[@]}"; do
        cd "${cwd}/replica_${replica}" || exit 1
        sed -i 's/#RESTART/RESTART/g' "plumed.dat" || exit 1
    done

else
    {
        # write header to log file
        echo "################################################################################"
        echo "Script: ${BASH_SOURCE[0]}"
        echo "Date: $(date)"
        echo "Host: $(hostname)"
        echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl"
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
            cp -np "${previous_archive_dir}/${previous_sim_name}.gro" "${previous_sim_name}.gro" || exit 1
            cp -np "${previous_archive_dir}/topol.top" "topol.top" || exit 1
            cp -np "${previous_archive_dir}/index.ndx" "index.ndx" || exit 1

            # copy mdp file
            cp "${mdp_file}" "${sim_name}.mdp" || exit 1
            sed -i 's/ref-t.*/ref-t                     = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
            sed -i 's/gen-temp.*/gen-temp                  = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
            sed -i 's/ref-p.*/ref-p                     = '"${PRESSURE_BAR} ${PRESSURE_BAR}/g" "${sim_name}.mdp" || exit 1
            # add vacuum parameters to mdp file
            if [[ "${VACUUM}" == 'True' ]]; then
                sed -i 's/^ewald-geometry .*/ewald-geometry            = 3dc/g' "${sim_name}.mdp" || exit 1
                sed -i 's/^pbc .*/pbc                       = xy/g' "${sim_name}.mdp" || exit 1
                sed -i 's/^nwall .*/nwall                     = 2/g' "${sim_name}.mdp" || exit 1
                if [[ "${N_SLAB}" -eq 2 ]]; then
                    sed -i 's/^wall-atomtype             = WR WL.*/wall-atomtype             = WR WR/g' "${sim_name}.mdp" || exit 1
                fi
            fi

            # copy plumed file
            cp "${dat_file}" "plumed.dat" || exit 1
            sed -i 's/{LOWER_WALL_HEIGHT}/'"${PE_WALL_MIN}"'/g' "plumed.dat" || exit 1
            sed -i 's/{UPPER_WALL_HEIGHT}/'"${PE_WALL_MAX}"'/g' "plumed.dat" || exit 1
            sed -i 's/{WALL_OFFSET}/'"${ATOM_OFFSET}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ATOM_REFERENCE}/'"${ATOM_REFERENCE}"'/g' "plumed.dat" || exit 1
            if [[ "${N_CALCIUM}" -eq '0' ]]; then
                sed -i 's/NDX_GROUP=Aqueous_Calcium/NDX_GROUP=Crystal_Top_Surface_Calcium/g' "plumed.dat" || exit 1
            fi
            if [[ "${N_CHAIN}" -gt '1' ]]; then
                sed -i '/WHOLEMOLECULES ENTITY0=gr_chain/d' "plumed.dat" || exit 1
            fi

            # append all "hot" atom names with '_' in [atoms] section only
            echo "DEBUG: Processing topology for replica_${replica}"
            cp "topol.top" "processed.top" || exit 1
            for atom in "${bias_atoms[@]}"; do
                perl -pi -e "s/\s+\d+\s+\K${atom} /${atom}_/g" "processed.top"
            done

            # run plumed processing tool to scale interactions
            echo "DEBUG: Plumed scaling of interactions for replica_${replica}"
            # shellcheck disable=SC2001
            idx=$(echo "${replica}" | sed 's/^0*//') # strip leading zeros
            echo "DEBUG: Plumed scaling of interactions with lambda = ${arr_lambda[${idx}]}"
            "${PLUMED_BIN}" partial_tempering "${arr_lambda[${idx}]}" \
                <"processed.top" \
                >"scaled.top"

            # create tpr file
            echo "DEBUG: Creating TPR file for replica_${replica}"
            "${GMX_BIN}" -nocopyright grompp \
                -f "${sim_name}.mdp" \
                -c "${previous_sim_name}.gro" \
                -r "${previous_sim_name}.gro" \
                -n "index.ndx" \
                -p "scaled.top" \
                -o "${sim_name}.tpr"

            # archive files that are no longer needed
            echo "DEBUG: Archiving files for replica_${replica}"
            mkdir -p "1-input"
            mv "topol.top" "processed.top" "${sim_name}.mdp" "1-input"
            cp "plumed.dat" "mdout.mdp" "scaled.top" "index.ndx" -t "1-input"

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
echo "INFO: Running equilibration HREMD simulation"
log_file="${log_dir}/${time_init}-2-mdrun.log"

if [[ -f "completed.txt" ]]; then
    echo "WARNING: completed.txt already exists"
    echo "INFO: Skipping equilibration HREMD simulation"

else
    {
        # write header to log file
        echo "################################################################################"
        echo "Script: ${BASH_SOURCE[0]}"
        echo "Date: $(date)"
        echo "Host: $(hostname)"
        echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl"
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
            -maxh "${WALLTIME_HOURS}" -pin 'on' \
            -multidir 'replica_'* -deffnm "${sim_name}" -cpi "${sim_name}.cpt" -plumed "plumed.dat" \
            -hrex -replex "${HREMD_N_STEPS}"

        sleep '10s' # wait for file system to catch up

        # make completed simulation text file if "${sim_name}.gro" exists
        if [[ -f "replica_00/${sim_name}.gro" ]]; then
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

{
    # write header to log file
    echo "################################################################################"
    echo "Script: ${BASH_SOURCE[0]}"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "System: ${MONOMER}-${BLOCK}-${CRYSTAL}-${SURFACE}-${SURFACE_SIZE}nm-${BOX_HEIGHT}nm-${N_MONOMER}mon-${N_CHAIN}chain-${N_CARBONATE}co3-${N_SODIUM}na-${N_CALCIUM}ca-${N_CHLORINE}cl"
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
            cp -np "./${sim_name}."* -t "${archive_sdir}" || exit 1
            cp -np 'index.ndx' ./*.dat ./*.data -t "${archive_sdir}" || exit 1
            mv 'scaled.top' "${archive_sdir}/topol.top" || exit 1
            rm "./${sim_name}."* || exit 1
            rm 'index.ndx' ./*.dat ./*.data ./*.cpt || exit 1
        else
            echo "WARNING: ${archive_sdir} already exists"
            echo "INFO: Skipping archiving simulation for replica_${replica}"
        fi

    done

    echo "INFO: All replicas cleaned successfully"
} >>"${log_file}" 2>&1

# #######################################################################################
# Completed #############################################################################
# #######################################################################################

# move to initial working directory
cd "${cwd_init}" || exit 1
echo "CRITICAL: Finished HREMD equilibration"
