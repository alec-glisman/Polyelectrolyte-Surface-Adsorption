#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-08-28
# Description: Script to equilibrate system T and P for MD simulations
# Usage      : ./equilibration.sh
# Notes      : Script assumes that global variables have been set in a
#             submission/input/*.sh script. Script should only be called from
#             the main run.sh script after initialization is complete.

# #######################################################################################
# Default Preferences ###################################################################
# #######################################################################################
echo "INFO: Setting default preferences"

# find path to this script
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
project_path="${script_path}/../.."

# python scripts
npt_script="${project_path}/python/mean_frame_xvg_2_col.py"

# Gromacs files
mdp_path="${project_path}/parameters/mdp/molecular-dynamics"
mdp_file_nvt="${mdp_path}/nvt_eqbm.mdp"
mdp_file_npt="${mdp_path}/npt_eqbm.mdp"
mdp_file_prod="${mdp_path}/${PRODUCTION_ENSEMBLE,,}_prod.mdp"

# Output files
cwd_init="$(pwd)"
cwd="${cwd_init}/2-equilibration"
log_file="equilibration.log"

# #######################################################################################
# Check for existing files ##############################################################
# #######################################################################################
echo "CRITICAL: Starting system equilibration"

# move to working directory
mkdir -p "${cwd}"
cd "${cwd}" || exit

# check if "2-output/system.gro" exists
if [[ -f "4-output/system.gro" ]]; then
    echo "WARNING: 4-output/system.gro already exists"
    echo "INFO: Exiting script"
    exit 0
fi

# #######################################################################################
# NVT equilibration #####################################################################
# #######################################################################################
echo "INFO: Starting NVT equilibration"
previous_sim_name="em"
previous_archive_dir="../1-energy-minimization/2-output"
sim_name="nvt_eqbm"
archive_dir="1-nvt"

# check if output gro file already exists
if [[ -f "${archive_dir}/${sim_name}.gro" ]]; then
    echo "WARNING: ${archive_dir}/${sim_name}.gro already exists"
    echo "INFO: Skipping NVT equilibration"
else
    {
        # copy output files from initialization
        cp -np "${previous_archive_dir}/system.gro" "${previous_sim_name}.gro" || exit 1
        cp -np "${previous_archive_dir}/topol.top" "topol.top" || exit 1
        cp -np "${previous_archive_dir}/index.ndx" "index.ndx" || exit 1

        # replace temperature in mdp file
        cp "${mdp_file_nvt}" "${sim_name}.mdp" || exit 1
        sed -i 's/ref-t.*/ref-t                     = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
        sed -i 's/gen-temp.*/gen-temp                  = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1

        # make tpr file for NVT equilibration
        "${GMX_BIN}" -quiet -nocopyright grompp \
            -f "${sim_name}.mdp" \
            -c "${previous_sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        # remove old gro file
        rm "${previous_sim_name}.gro" || exit 1

        # run NVT equilibration
        "${MPI_BIN}" -np '1' \
            --map-by "ppr:1:node:PE=${CPU_THREADS}" \
            --use-hwthread-cpus --bind-to 'hwthread' \
            "${GMX_BIN}" -quiet -nocopyright mdrun -v \
            -deffnm "${sim_name}" -cpi "${sim_name}.cpt" \
            -pin on -pinoffset "${PIN_OFFSET}" -pinstride 1 -ntomp "${CPU_THREADS}" \
            -gpu_id "${GPU_IDS}" || exit 1

        # convert final xtc frame to pdb file
        "${GMX_BIN}" -quiet -nocopyright trjconv \
            -f "${sim_name}.xtc" \
            -s "${sim_name}.tpr" \
            -o "${sim_name}.pdb" \
            -pbc 'mol' -ur 'compact' -conect \
            -dump '100000000000' <<EOF
System
EOF

        # plot system parameters over time
        params=('Potential' 'Kinetic-En.' 'Total-Energy' 'Temperature' 'Pressure')
        for param in "${params[@]}"; do
            filename="${param,,}"
            "${GMX_BIN}" -quiet -nocopyright energy \
                -f "${sim_name}.edr" \
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

        # move simulation files to archive directory
        mkdir -p "${archive_dir}"
        cp -np "${sim_name}."* -t "${archive_dir}/" || exit 1
        rm "${sim_name}."* || exit 1
        cp -np "mdout.mdp" -t "${archive_dir}/" || exit 1
        rm ./*.cpt mdout.mdp || exit 1
        # move xvg and png files to archive directory
        mkdir -p "${archive_dir}/figures"
        cp -np ./*.xvg -t "${archive_dir}/figures/" || exit 1
        cp -np ./*.png -t "${archive_dir}/figures/" || exit 1
        rm ./*.xvg ./*.png || exit 1
        # copy gro file to current directory
        cp -np "${archive_dir}/${sim_name}.gro" "${sim_name}.gro" || exit 1
    } >>"${log_file}" 2>&1
fi

# #######################################################################################
# NPT equilibration #####################################################################
# #######################################################################################
echo "INFO: Starting NPT equilibration"
previous_sim_name="${sim_name}"
previous_archive_dir="${archive_dir}"
sim_name="npt_eqbm"
archive_dir="2-npt"

# check if output gro file already exists
if [[ -f "${archive_dir}/${sim_name}.gro" ]]; then
    echo "WARNING: ${archive_dir}/${sim_name}.gro already exists"
    echo "INFO: Skipping NPT equilibration"
else
    {
        # copy output files from NVT equilibration
        cp -np "${previous_archive_dir}/${previous_sim_name}.gro" "${previous_sim_name}.gro" || exit 1

        # replace temperature and pressure in mdp file
        cp "${mdp_file_npt}" "${sim_name}.mdp" || exit 1
        sed -i 's/ref-t.*/ref-t                     = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
        sed -i 's/gen-temp.*/gen-temp                  = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
        sed -i 's/ref-p.*/ref-p                     = '"${PRESSURE_BAR} ${PRESSURE_BAR}/g" "${sim_name}.mdp" || exit 1

        # make tpr file
        "${GMX_BIN}" -quiet -nocopyright grompp \
            -f "${sim_name}.mdp" \
            -c "${previous_sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        rm "${previous_sim_name}.gro" || exit 1

        # call mdrun
        "${MPI_BIN}" -np '1' \
            --map-by "ppr:1:node:PE=${CPU_THREADS}" \
            --use-hwthread-cpus --bind-to 'hwthread' \
            "${GMX_BIN}" -quiet -nocopyright mdrun -v \
            -deffnm "${sim_name}" -cpi "${sim_name}.cpt" \
            -pin on -pinoffset "${PIN_OFFSET}" -pinstride 1 -ntomp "${CPU_THREADS}" \
            -gpu_id "${GPU_IDS}" || exit 1

        # plot system parameters over time
        params=('Potential' 'Kinetic-En.' 'Total-Energy' 'Temperature' 'Pressure' 'Density')
        for param in "${params[@]}"; do
            filename="${param,,}"
            "${GMX_BIN}" -quiet -nocopyright energy \
                -f "${sim_name}.edr" \
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

        # select a representative frame from the NPT equilibration and make new gro file
        python3 "${npt_script}" \
            --xvg_filename "density.xvg" \
            --xtc_filename "${sim_name}.xtc" \
            --gro_filename "${sim_name}.gro" \
            --percentile '0.4'

        # convert final gro file to pdb file
        "${GMX_BIN}" -quiet -nocopyright trjconv \
            -f "${sim_name}.gro" \
            -s "${sim_name}.tpr" \
            -o "${sim_name}.pdb" \
            -pbc 'mol' -ur 'compact' -conect <<EOF
System
EOF

        # move simulation files to archive directory
        mkdir -p "${archive_dir}"
        cp -np "${sim_name}."* -t "${archive_dir}/" || exit 1
        rm "${sim_name}."* || exit 1
        cp -np "mdout.mdp" -t "${archive_dir}/" || exit 1
        rm ./*.cpt mdout.mdp || exit 1
        # move xvg and png files to archive directory
        mkdir -p "${archive_dir}/figures"
        cp -np ./*.xvg -t "${archive_dir}/figures/" || exit 1
        cp -np ./*.png -t "${archive_dir}/figures/" || exit 1
        rm ./*.xvg ./*.png || exit 1
        # copy gro file to current directory
        cp -np "${archive_dir}/${sim_name}.gro" "${sim_name}.gro" || exit 1
    } >>"${log_file}" 2>&1
fi

# Print initial and final system volumes
# get last line of previous sim gro file
previous_sim_gro_last_line="$(tail -n 1 "${previous_archive_dir}/${previous_sim_name}.gro")"
previous_sim_gro_box_dimensions="$(echo "${previous_sim_gro_last_line}" | awk '{print $1, $2, $3}')"
echo "DEBUG: NVT system dimensions: ${previous_sim_gro_box_dimensions}"
# get last line of current sim gro file
sim_gro_last_line="$(tail -n 1 "${archive_dir}/${sim_name}.gro")"
sim_gro_box_dimensions="$(echo "${sim_gro_last_line}" | awk '{print $1, $2, $3}')"
echo "DEBUG: NPT system dimensions: ${sim_gro_box_dimensions}"
# calculate percent change in each dimension
# shellcheck disable=SC2206
previous_sim_gro_box_dimensions_array=(${previous_sim_gro_box_dimensions})
# shellcheck disable=SC2206
sim_gro_box_dimensions_array=(${sim_gro_box_dimensions})
for i in "${!previous_sim_gro_box_dimensions_array[@]}"; do
    previous_sim_gro_box_dimension="${previous_sim_gro_box_dimensions_array[i]}"
    sim_gro_box_dimension="${sim_gro_box_dimensions_array[i]}"
    percent_change="$(echo "scale=4; (${sim_gro_box_dimension} - ${previous_sim_gro_box_dimension}) / ${previous_sim_gro_box_dimension} * 100" | bc)"
    echo "DEBUG: Percent change in dimension ${i}: ${percent_change}"'%'
done

# #######################################################################################
# Production equilibration ##############################################################
# #######################################################################################
echo "INFO: Starting production equilibration"
previous_sim_name="${sim_name}"
previous_archive_dir="${archive_dir}"
sim_name="prod_eqbm"
archive_dir="3-pre-production"

# check if output gro file already exists
if [[ -f "${archive_dir}/${sim_name}.gro" ]]; then
    echo "WARNING: ${archive_dir}/${sim_name}.gro already exists"
    echo "INFO: Skipping NPT equilibration"
else
    {
        # copy output files from NVT equilibration
        cp -np "${previous_archive_dir}/${previous_sim_name}.gro" "${previous_sim_name}.gro" || exit 1

        # replace temperature and pressure in mdp file
        cp "${mdp_file_prod}" "${sim_name}.mdp" || exit 1
        sed -i 's/ref-t.*/ref-t                     = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
        sed -i 's/gen-temp.*/gen-temp                  = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
        sed -i 's/ref-p.*/ref-p                     = '"${PRESSURE_BAR} ${PRESSURE_BAR}/g" "${sim_name}.mdp" || exit 1

        # make tpr file
        "${GMX_BIN}" -quiet -nocopyright grompp \
            -f "${sim_name}.mdp" \
            -c "${previous_sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'
        rm "${previous_sim_name}.gro" || exit 1

        # call mdrun
        "${MPI_BIN}" -np '1' \
            --map-by "ppr:1:node:PE=${CPU_THREADS}" \
            --use-hwthread-cpus --bind-to 'hwthread' \
            "${GMX_BIN}" -quiet -nocopyright mdrun -v \
            -deffnm "${sim_name}" -cpi "${sim_name}.cpt" \
            -pin on -pinoffset "${PIN_OFFSET}" -pinstride 1 -ntomp "${CPU_THREADS}" \
            -gpu_id "${GPU_IDS}" || exit 1

        # convert final xtc frame to pdb file
        "${GMX_BIN}" -quiet -nocopyright trjconv \
            -f "${sim_name}.xtc" \
            -s "${sim_name}.tpr" \
            -o "${sim_name}.pdb" \
            -pbc 'mol' -ur 'compact' -conect \
            -dump '100000000000' <<EOF
System
EOF

        # plot system parameters over time
        params=('Potential' 'Kinetic-En.' 'Total-Energy' 'Temperature' 'Pressure')
        if [[ "${PRODUCTION_ENSEMBLE^^}" == "NPT" ]]; then
            params+=('Density')
        fi
        for param in "${params[@]}"; do
            filename="${param,,}"
            "${GMX_BIN}" -quiet -nocopyright energy \
                -f "${sim_name}.edr" \
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

        # move simulation files to archive directory
        mkdir -p "${archive_dir}"
        cp -np "${sim_name}."* -t "${archive_dir}/" || exit 1
        rm "${sim_name}."* || exit 1
        cp -np "mdout.mdp" -t "${archive_dir}/" || exit 1
        rm ./*.cpt mdout.mdp || exit 1
        # move xvg and png files to archive directory
        mkdir -p "${archive_dir}/figures"
        cp -np ./*.xvg -t "${archive_dir}/figures/" || exit 1
        cp -np ./*.png -t "${archive_dir}/figures/" || exit 1
        rm ./*.xvg ./*.png || exit 1
        # copy gro file to current directory
        cp -np "${archive_dir}/${sim_name}.gro" "${sim_name}.gro" || exit 1
    } >>"${log_file}" 2>&1
fi

# #######################################################################################
# Clean up ##############################################################################
# #######################################################################################
echo "INFO: Cleaning up"
previous_sim_name="${sim_name}"
sim_name="prod_eqbm"
previous_archive_dir="${archive_dir}"
archive_dir="4-output"

# check if output gro file already exists
if [[ -f "${archive_dir}/${sim_name}.gro" ]]; then
    echo "WARNING: ${archive_dir}/${sim_name}.gro already exists"
    echo "INFO: Skipping NPT equilibration"
else
    {
        # copy minimal set of files to archive directory
        mkdir -p "${archive_dir}"
        cp -np "${previous_archive_dir}/${sim_name}.gro" "${archive_dir}/${sim_name}.gro" || exit 1
        cp -np "${previous_archive_dir}/${sim_name}.pdb" "${archive_dir}/${sim_name}.pdb" || exit 1
        cp -np "topol.top" "${archive_dir}/topol.top" || exit 1
        cp -np "index.ndx" "${archive_dir}/index.ndx" || exit 1
    } >>"${log_file}" 2>&1
fi

echo "CRITICAL: Finished system equilibration"
