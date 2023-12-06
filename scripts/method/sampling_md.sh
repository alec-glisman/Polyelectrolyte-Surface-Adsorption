#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-09-06
# Usage      : ./sampling_md.sh
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

# initial time with _ as separator
time_init="$(date +%Y_%m_%d_%H_%M_%S)"

# Output files
cwd_init="$(pwd)"
cwd="${cwd_init}/3-sampling-md"
log_dir="${cwd}/logs"
log_file="${log_dir}/${time_init}-md.log"

# #######################################################################################
# Check for existing files ##############################################################
# #######################################################################################
echo "CRITICAL: Starting MD production"

# move to working directory
mkdir -p "${cwd}"
mkdir -p "${log_dir}"
cd "${cwd}" || exit

# check if output gro file already exists
if [[ -f "output/system.gro" ]]; then
    echo "WARNING: output/system.gro already exists"
    echo "INFO: Exiting script"
    exit 0
fi

# #######################################################################################
# Run simulation ########################################################################
# #######################################################################################
echo "INFO: Running production MD simulation"
previous_sim_name="prod_eqbm"
previous_archive_dir="${cwd_init}/2-equilibration/4-output"
sim_name="prod_md"

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
} >>"${log_file}" 2>&1

if [[ -f "completed.txt" ]]; then
    echo "WARNING: completed.txt already exists"
    echo "INFO: Skipping production MD simulation"

elif [[ "${FLAG_ARCHIVE}" = true ]]; then
    echo "WARNING: Archive flag is set, mdrun will not be called"
    echo "INFO: Skipping production MD simulation"

else
    {
        # copy output files from equilibration
        cp -np "${previous_archive_dir}/${previous_sim_name}.gro" "${previous_sim_name}.gro" || exit 1
        cp -np "${previous_archive_dir}/topol.top" "topol.top" || exit 1
        cp -np "${previous_archive_dir}/index.ndx" "index.ndx" || exit 1

        # if tpr file does not exist, create it
        if [[ ! -f "${sim_name}.tpr" ]]; then
            echo "DEBUG: Creating tpr file"

            # copy mdp file
            cp "${mdp_file}" "${sim_name}.mdp" || exit 1
            sed -i 's/ref-t.*/ref-t                     = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
            sed -i 's/gen-temp.*/gen-temp                  = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
            sed -i 's/ref-p.*/ref-p                     = '"${PRESSURE_BAR} ${PRESSURE_BAR}/g" "${sim_name}.mdp" || exit 1

            # create tpr file
            "${GMX_BIN}" -nocopyright grompp \
                -f "${sim_name}.mdp" \
                -c "${previous_sim_name}.gro" \
                -r "${previous_sim_name}.gro" \
                -n "index.ndx" \
                -p "topol.top" \
                -o "${sim_name}.tpr"
            rm "${previous_sim_name}.gro" || exit 1
        fi

        # call mdrun
        "${MPI_BIN}" -np '1' \
            --map-by "ppr:1:node:PE=${CPU_THREADS}" \
            --use-hwthread-cpus --bind-to 'hwthread' \
            "${GMX_BIN}" -nocopyright mdrun -v \
            -maxh "${WALLTIME_HOURS}" \
            -deffnm "${sim_name}" -cpi "${sim_name}.cpt" \
            -pin on -pinoffset "${PIN_OFFSET}" -pinstride 1 -ntomp "${CPU_THREADS}" \
            -gpu_id "${GPU_IDS}" \
            -noappend || exit 1

        # make completed simulation text file
        touch "completed.txt"
        # write completed simulation text file
        echo "completed: $(date)" >"completed.txt"

    } >>"${log_file}" 2>&1
fi

# #######################################################################################
# Concatenate trajectories ##############################################################
# #######################################################################################
echo "INFO: Archiving simulation"
log_file="${log_dir}/${time_init}-concatenation.log"

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
} >>"${log_file}" 2>&1

# rsync output files to archive directory
archive_dir="1-runs"
{
    rsync --archive --verbose --progress --human-readable --itemize-changes \
        "${sim_name}."* "${archive_dir}/" || exit 1
} >>"${log_file}" 2>&1

# concatenate files into single trajectory
echo "INFO: Concatenating trajectories"
concat_dir="2-concatenated"
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
} >>"${log_file}" 2>&1

# dump trajectory without solvent
echo "INFO: Dumping trajectory without solvent"
nosol_dir="3-no-solvent"
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

} >>"${log_file}" 2>&1

# #######################################################################################
# Analysis ##############################################################################
# #######################################################################################
echo "INFO: Analyzing trajectory"
log_file="${log_dir}/${time_init}-analysis.log"

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
} >>"${log_file}" 2>&1

{
    # plot system parameters over time
    params=('Potential' 'Kinetic-En.' 'Total-Energy' 'Temperature' 'Pressure')
    if [[ "${PRODUCTION_ENSEMBLE^^}" == "NPT" ]]; then
        params+=('Density')
    fi
    echo "DEBUG: Parameters to plot: ${params[*]}"
    for param in "${params[@]}"; do
        filename="${param,,}"
        "${GMX_BIN}" -nocopyright energy \
            -f "${concat_dir}/${sim_name}.edr" \
            -o "${filename}.xvg" <<EOF
${param}
0
EOF
        # convert xvg to png
        gracebat -nxy "${filename}.xvg" \
            -hdevice "PNG" \
            -autoscale "xy" \
            -printfile "${filename}.png" \
            -fixed "3840" "2160"
    done

    # copy all xvg files to xvg directory
    mkdir -p "xvg"
    cp -p ./*.xvg "xvg/" || exit 1
    rm ./*.xvg || exit 1

    # copy all png files to png directory
    mkdir -p "png"
    cp -p ./*.png "png/" || exit 1
    rm ./*.png || exit 1
} >>"${log_file}" 2>&1

# #######################################################################################
# Clean Up ##############################################################################
# #######################################################################################
echo "INFO: Cleaning up"
log_file="cleanup.log"

# iterate over directories and delete backup files
for dir in "${archive_dir}" "${concat_dir}" "${nosol_dir}" "."; do
    find "${dir}" -type f -name '#*#' -delete || true
done

# move to initial working directory
cd "${cwd_init}" || exit 1

echo "CRITICAL: Finished MD sampling"
