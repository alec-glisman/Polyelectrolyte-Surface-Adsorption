#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-10-18
# Usage      : ./sampling_metadynamics.sh
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
dat_path="${project_path}/parameters/plumed/metadynamics"
dat_file="${dat_path}/plumed.dat"

# initial time with _ as separator
time_init="$(date +%Y_%m_%d_%H_%M_%S)"

# Output files
cwd_init="$(pwd)"
cwd="${cwd_init}/3-sampling-metadynamics"
log_dir="${cwd}/logs"

# #######################################################################################
# Check for existing files ##############################################################
# #######################################################################################
echo "CRITICAL: Starting Metadynamics production"
log_file="${log_dir}/${time_init}-md.log"

# move to working directory
mkdir -p "${cwd}"
cd "${cwd}" || exit
mkdir -p "${log_dir}"

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

# #######################################################################################
# Prepare simulation ####################################################################
# #######################################################################################
previous_sim_name="prod_eqbm"
previous_archive_dir="${cwd_init}/2-equilibration/4-output"
sim_name="prod_opes_explore"

if [[ ! -f "${sim_name}.tpr" ]]; then
    echo "INFO: Preparing simulation tpr file"
    {
        # copy output files from equilibration
        cp -np "${previous_archive_dir}/${previous_sim_name}.gro" "${previous_sim_name}.gro" || exit 1
        cp -np "${previous_archive_dir}/topol.top" "topol.top" || exit 1
        cp -np "${previous_archive_dir}/index.ndx" "index.ndx" || exit 1

        # copy mdp file
        cp "${mdp_file}" "${sim_name}.mdp" || exit 1
        sed -i 's/ref-t.*/ref-t                     = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
        sed -i 's/gen-temp.*/gen-temp                  = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
        sed -i 's/ref-p.*/ref-p                     = '"${PRESSURE_BAR} ${PRESSURE_BAR}/g" "${sim_name}.mdp" || exit 1
        # small surfaces have smaller cutoffs
        if [[ "${SURFACE_SIZE}" -lt 4 ]]; then
            sed -i 's/^rlist.*/rlist = 0.7/g' "${sim_name}.mdp" || exit 1
            sed -i 's/^rcoulomb.*/rcoulomb = 0.7/g' "${sim_name}.mdp" || exit 1
            sed -i 's/^rvdw.*/rvdw = 0.7/g' "${sim_name}.mdp" || exit 1
        fi
        # add vacuum parameters to mdp file
        if [[ "${VACUUM_HEIGHT}" -gt 0 ]]; then
            sed -i 's/^ewald-geometry .*/ewald-geometry            = 3dc/g' "${sim_name}.mdp" || exit 1
            sed -i 's/^pbc .*/pbc                       = xy/g' "${sim_name}.mdp" || exit 1
            sed -i 's/^nwall .*/nwall                     = 2/g' "${sim_name}.mdp" || exit 1
        fi

        # copy plumed file
        cp "${dat_file}" "plumed.dat" || exit 1
        sed -i 's/{LOWER_WALL_HEIGHT}/'"${PE_WALL_MIN}"'/g' "plumed.dat" || exit 1
        sed -i 's/{UPPER_WALL_HEIGHT}/'"${PE_WALL_MAX}"'/g' "plumed.dat" || exit 1
        sed -i 's/{WALL_OFFSET}/'"${ATOM_OFFSET}"'/g' "plumed.dat" || exit 1
        sed -i 's/{ATOM_REFERENCE}/'"${ATOM_REFERENCE}"'/g' "plumed.dat" || exit 1
        sed -i "s/{METAD_PACE}/${METAD_PACE}/g" 'plumed.dat' || exit 1
        sed -i "s/{METAD_HEIGHT}/${METAD_HEIGHT}/g" 'plumed.dat' || exit 1
        sed -i "s/{METAD_SIGMA}/${METAD_SIGMA}/g" 'plumed.dat' || exit 1
        sed -i "s/{METAD_BIASFACTOR}/${METAD_BIASFACTOR}/g" 'plumed.dat' || exit 1
        sed -i "s/{TEMPERATURE_K}/${TEMPERATURE_K}/g" 'plumed.dat' || exit 1
        sed -i "s/{METAD_GRID_MIN}/${METAD_GRID_MIN}/g" 'plumed.dat' || exit 1
        sed -i "s/{METAD_GRID_MAX}/${METAD_GRID_MAX}/g" 'plumed.dat' || exit 1
        sed -i "s/{METAD_GRID_SPACING}/${METAD_GRID_SPACING}/g" 'plumed.dat' || exit 1
        if [[ "${N_CALCIUM}" -eq '0' ]]; then
            sed -i 's/NDX_GROUP=Aqueous_Calcium/NDX_GROUP=Crystal_Top_Surface_Calcium/g' "plumed.dat" || exit 1
        fi

        # create tpr file
        "${GMX_BIN}" -nocopyright grompp \
            -f "${sim_name}.mdp" \
            -c "${previous_sim_name}.gro" \
            -r "${previous_sim_name}.gro" \
            -n "index.ndx" \
            -p "topol.top" \
            -o "${sim_name}.tpr"
        rm "${previous_sim_name}.gro" || exit 1
    } >>"${log_file}" 2>&1

else
    echo "DEBUG: Using existing tpr file"
    sed -i 's/#RESTART/RESTART/g' "plumed.dat" || exit 1

fi

# #######################################################################################
# Run simulation ########################################################################
# #######################################################################################
echo "INFO: Running production Metadynamics simulation"

if [[ -f "completed.txt" ]]; then
    echo "WARNING: completed.txt already exists"
    echo "INFO: Skipping production Metadynamics simulation"

elif [[ "${FLAG_ARCHIVE}" = true ]]; then
    echo "WARNING: Archive flag is set, mdrun will not be called"
    echo "INFO: Skipping production Metadynamics simulation"

else
    echo "INFO: Calling mdrun"
    {
        # shellcheck disable=SC2153,SC2086
        "${GMX_BIN}" -nocopyright mdrun -v \
            -maxh "${WALLTIME_HOURS}" \
            -deffnm "${sim_name}" -cpi "${sim_name}.cpt" \
            -plumed "plumed.dat" \
            ${GMX_CPU_ARGS} ${GMX_GPU_ARGS} \
            -noappend
    } >>"${log_file}" 2>&1

    # check if gromacs simulation completed or was terminated
    echo "INFO: checking if simulation completed successfully"
    bool_completed=false
    while IFS= read -r line; do
        if [[ "${line}" == *"writing final coordinates."* ]]; then
            bool_completed=true
        fi
    done <"${log_file}"
    echo "DEBUG: bool_completed = ${bool_completed}"

    # make completed simulation text file if simulation completed successfully
    if [[ "${bool_completed}" = true ]]; then
        echo "INFO: simulation completed successfully"
        touch "completed.txt"
        echo "completed: $(date)" >"completed.txt"

    # otherwise, exit script without error
    else
        echo "WARNING: ${sim_name}.gro does not exist. simulation did not complete successfully"
        echo "INFO: exiting script"
        exit 0
    fi

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
if [[ ! -d "${archive_dir}" ]] || [[ "${FLAG_ARCHIVE}" = true ]]; then
    echo "INFO: Archiving simulation"
    {
        rsync --archive --verbose --progress --human-readable --itemize-changes \
            "${sim_name}."* "${archive_dir}/" || exit 1
        rsync --archive --verbose --progress --human-readable --itemize-changes \
            ./*.data "${archive_dir}/" || exit 1
        rsync --archive --verbose --progress --human-readable --itemize-changes \
            ./*.dat "${archive_dir}/" || exit 1
        rsync --archive --verbose --progress --human-readable --itemize-changes \
            ./*.Kernels* "${archive_dir}/" || exit 1
    } >>"${log_file}" 2>&1
else
    echo "INFO: Skipping archiving simulation"
fi

# concatenate files into single trajectory
concat_dir="2-concatenated"
if [[ ! -d "${concat_dir}" ]] || [[ "${FLAG_ARCHIVE}" = true ]]; then
    echo "INFO: Concatenating trajectories"
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
    } >>"${log_file}" 2>&1
else
    echo "INFO: Skipping concatenation"
fi

# dump trajectory without solvent
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
    } >>"${log_file}" 2>&1
else
    echo "INFO: Skipping dumping trajectory without solvent"
fi

# #######################################################################################
# Analysis ##############################################################################
# #######################################################################################
log_file="${log_dir}/${time_init}-analysis.log"

if [[ ! -d "png" ]] || [[ "${FLAG_ARCHIVE}" = true ]]; then
    echo "INFO: Analyzing trajectory"
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

else
    echo "INFO: Skipping analysis"
fi

# #######################################################################################
# Clean Up ##############################################################################
# #######################################################################################
echo "INFO: Cleaning up"
log_file="${log_dir}/${time_init}-cleanup.log"

{
    # iterate over directories and delete backup files
    for dir in "${archive_dir}" "${concat_dir}" "${nosol_dir}" "."; do
        find "${dir}" -type f -name '#*#' -delete || true
    done

    # move to initial working directory
    cd "${cwd_init}" || exit 1
} >>"${log_file}" 2>&1

echo "CRITICAL: Finished Metadynamics production"
