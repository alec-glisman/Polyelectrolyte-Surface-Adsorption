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

# built-in shell options
set -o errexit  # exit when a command fails. Add || true to commands allowed to fail
set -o nounset  # exit when script tries to use undeclared variables
set -o pipefail # exit when a command in a pipe fails

# start time
start_time="$(date +%s)"
echo "INFO: Starting system equilibration at $(date)"

# #######################################################################################
# Default Preferences ###################################################################
# #######################################################################################
echo "INFO: Setting default preferences"

# find path to this script
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
project_path="${script_path}/../.."

# python scripts
npt_script="${project_path}/python/mean_frame_xvg_2_col.py"

# Plumed files
dat_path="${project_path}/parameters/plumed/harmonic"
if [[ "${N_CHAIN}" -gt 0 ]]; then
    dat_file="${dat_path}/plumed.dat"
else
    dat_file="${dat_path}/empty.dat"
fi

# Gromacs files
mdp_path="${project_path}/parameters/mdp/molecular-dynamics"
mdp_file_nvt="${mdp_path}/nvt_eqbm.mdp"
mdp_file_npt="${mdp_path}/npt_eqbm.mdp"
mdp_file_prod="${mdp_path}/${PRODUCTION_ENSEMBLE,,}_eqbm.mdp"

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

        cp "${mdp_file_nvt}" "${sim_name}.mdp" || exit 1
        # freeze atoms in mdp file
        sed -i 's/freezegrps.*/freezegrps = Crystal/g' "${sim_name}.mdp" || exit 1
        # replace temperature in mdp file
        sed -i 's/ref-t.*/ref-t                     = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
        sed -i 's/gen-temp.*/gen-temp                  = '"${TEMPERATURE_K}/g" "${sim_name}.mdp" || exit 1
        # small surfaces have smaller cutoffs
        if [[ "${SURFACE_SIZE}" -lt 4 ]]; then
            sed -i 's/^rlist.*/rlist = 0.7/g' "${sim_name}.mdp" || exit 1
            sed -i 's/^rcoulomb.*/rcoulomb = 0.7/g' "${sim_name}.mdp" || exit 1
            sed -i 's/^rvdw.*/rvdw = 0.7/g' "${sim_name}.mdp" || exit 1
        fi
        # add vacuum parameters to mdp file
        if [[ "${VACUUM}" == 'True' ]]; then
            sed -i 's/^ewald-geometry .*/ewald-geometry            = 3dc/g' "${sim_name}.mdp" || exit 1
            sed -i 's/^pbc .*/pbc                       = xy/g' "${sim_name}.mdp" || exit 1
            sed -i 's/^nwall .*/nwall                     = 2/g' "${sim_name}.mdp" || exit 1
        fi

        # make tpr file for NVT equilibration
        "${GMX_BIN}" -nocopyright grompp \
            -f "${sim_name}.mdp" \
            -c "${previous_sim_name}.gro" \
            -r "${previous_sim_name}.gro" \
            -n "index.ndx" \
            -p "topol.top" \
            -o "${sim_name}.tpr"
        # remove old gro file
        rm "${previous_sim_name}.gro" || exit 1

        # run NVT equilibration
        # shellcheck disable=SC2086
        "${GMX_BIN}" -nocopyright mdrun -v \
            -deffnm "${sim_name}" -cpi "${sim_name}.cpt" \
            ${GMX_CPU_ARGS} ${GMX_GPU_ARGS} || exit 1

        # convert final xtc frame to pdb file
        "${GMX_BIN}" -nocopyright trjconv \
            -f "${sim_name}.xtc" \
            -s "${sim_name}.tpr" \
            -o "${sim_name}.pdb" \
            -pbc 'mol' -ur 'tric' -conect \
            -dump '100000000000' <<EOF
System
EOF

        # plot system parameters over time
        params=('Potential' 'Kinetic-En.' 'Total-Energy' 'Temperature' 'Pressure')
        for param in "${params[@]}"; do
            filename="${param,,}"
            "${GMX_BIN}" -nocopyright energy \
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
        rm -f ./*.cpt || exit 1
        rm mdout.mdp || exit 1
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

        cp "${mdp_file_npt}" "${sim_name}.mdp" || exit 1
        # freeze atoms in mdp file
        sed -i 's/freezegrps.*/freezegrps = Crystal/g' "${sim_name}.mdp" || exit 1
        # replace temperature and pressure in mdp file
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
        if [[ "${VACUUM}" == 'True' ]]; then
            sed -i 's/^ewald-geometry .*/ewald-geometry            = 3dc/g' "${sim_name}.mdp" || exit 1
            sed -i 's/^pbc .*/pbc                       = xy/g' "${sim_name}.mdp" || exit 1
            sed -i 's/^nwall .*/nwall                     = 2/g' "${sim_name}.mdp" || exit 1
        fi

        # make tpr file
        "${GMX_BIN}" -nocopyright grompp \
            -f "${sim_name}.mdp" \
            -c "${previous_sim_name}.gro" \
            -r "${previous_sim_name}.gro" \
            -n "index.ndx" \
            -p "topol.top" \
            -o "${sim_name}.tpr"
        rm "${previous_sim_name}.gro" || exit 1

        # plumed performance
        export PLUMED_NUM_THREADS="${CPU_THREADS}"

        # run NPT equilibration
        # shellcheck disable=SC2086
        "${GMX_BIN}" -nocopyright mdrun -v \
            -deffnm "${sim_name}" -cpi "${sim_name}.cpt" \
            ${GMX_CPU_ARGS} ${GMX_GPU_ARGS} || exit 1

        # plot system parameters over time
        params=('Potential' 'Kinetic-En.' 'Total-Energy' 'Temperature' 'Pressure' 'Density')
        for param in "${params[@]}"; do
            filename="${param,,}"
            "${GMX_BIN}" -nocopyright energy \
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
        "${GMX_BIN}" -nocopyright trjconv \
            -f "${sim_name}.gro" \
            -s "${sim_name}.tpr" \
            -o "${sim_name}.pdb" \
            -pbc 'mol' -ur 'tric' -conect <<EOF
System
EOF

        # move simulation files to archive directory
        mkdir -p "${archive_dir}"
        cp -np "${sim_name}."* -t "${archive_dir}/" || exit 1
        rm "${sim_name}."* || exit 1
        cp -np "mdout.mdp" -t "${archive_dir}/" || exit 1
        rm -f ./*.cpt || exit 1
        rm mdout.mdp || exit 1
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
# Add Second Slab  ######################################################################
# #######################################################################################
z_buffer='0.2'

if [[ "${N_SLAB}" -eq 2 ]]; then
    echo "INFO: Adding second slab"

    # check if output gro file already exists
    if [[ -f "${sim_name}_2slab.gro" ]]; then
        echo "DEBUG: Second slab already added"
    else
        {
            # copy crystal.pdb from initialization
            cp -np "../1-energy-minimization/crystal.gro" "crystal.gro" || exit 1

            # find maximum z-coordinate of box from previous gro file
            box_dim="$(tail -n 1 "${archive_dir}/${sim_name}.gro")"
            z_height="$(echo "${box_dim}" | awk '{print $3}')"

            # calculate z-height of crystal and move slab to desired position
            z_coords="$(awk 'NR>2 {print $6}' "crystal.gro")"
            z_coords="$(echo "${z_coords}" | head -n -1 | sort -n)"
            z_max="$(echo "${z_coords}" | tail -n 1)"
            z_min="$(echo "${z_coords}" | head -n 1)"
            z_height_crystal="$(echo "scale=5; ${z_max} - ${z_min}" | bc)"
            z_translate="$(echo "scale=5; ${z_height} + ${z_max}" | bc)"
            z_height_2slab="$(echo "scale=5; ${z_height} + ${z_height_crystal} + ${z_buffer}" | bc)"

            # insert "-" at column 39 in all lines of gro file to reflect crystal on z-axis
            awk '{print substr($0,1,38)"-"substr($0,40)}' "crystal.gro" >"crystal_reflected.gro"
            head -n 2 crystal.gro >temp.txt
            tail -n +3 crystal_reflected.gro >>temp.txt
            head -n -1 temp.txt >temp2.txt
            mv temp2.txt temp.txt
            tail -n 1 crystal.gro >>temp.txt
            mv temp.txt crystal_reflected.gro

            # move reflected crystal to top of box
            "${GMX_BIN}" editconf \
                -f "crystal_reflected.gro" \
                -o "crystal_reflected.gro" \
                -translate 0 0 "${z_translate}"

            # get crystal coordinates for a dat file
            z_cryst="$(awk 'NR>2 {print $6}' "crystal_reflected.gro")"
            z_cryst="$(echo "${z_cryst}" | head -n -1)"
            y_cryst="$(awk 'NR>2 {print $5}' "crystal_reflected.gro")"
            y_cryst="$(echo "${y_cryst}" | head -n -1)"
            x_cryst="$(awk 'NR>2 {print $4}' "crystal_reflected.gro")"
            x_cryst="$(echo "${x_cryst}" | head -n -1)"
            paste <(echo "${x_cryst}") <(echo "${y_cryst}") <(echo "${z_cryst}") >positions.dat

            # increase box size in z-dimension by z_height_crystal
            cp -np "${archive_dir}/${sim_name}.gro" "${sim_name}_2slab_pre.gro" || exit 1
            sed -i "s/${z_height}/${z_height_2slab}/" "${sim_name}_2slab_pre.gro"

            # convert box and crystal to pdb files
            "${GMX_BIN}" editconf \
                -f "${sim_name}_2slab_pre.gro" \
                -o "${sim_name}_2slab_pre.pdb"
            sed -i '/^TER/d' "${sim_name}_2slab_pre.pdb"
            sed -i '/^ENDMDL/d' "${sim_name}_2slab_pre.pdb"
            "${GMX_BIN}" editconf \
                -f "crystal_reflected.gro" \
                -o "crystal_reflected.pdb"
            sed -i "/^TITLE.*/d" "crystal_reflected.pdb"
            sed -i "/^REMARK.*/d" "crystal_reflected.pdb"
            sed -i "/^CRYST1.*/d" "crystal_reflected.pdb"
            sed -i "/^MODEL.*/d" "crystal_reflected.pdb"

            # merge pdb files into gro file
            \cat "${sim_name}_2slab_pre.pdb" "crystal_reflected.pdb" >"${sim_name}_2slab.pdb"
            "${GMX_BIN}" editconf \
                -f "${sim_name}_2slab.pdb" \
                -o "${sim_name}_2slab.gro"

            # TODO: make new topology files with 2slab

            # TODO: make new index file

        } >>"${log_file}" 2>&1
    fi

    echo "DEBUG: Crystal height: ${z_height_crystal}"
fi

# #######################################################################################
# Make box orthorhombic ##############################################################
# #######################################################################################
echo "INFO: Making box orthorhombic"
{
    cp -np "${archive_dir}/${sim_name}.gro" "${archive_dir}/${sim_name}_triclinic.gro"
    "${GMX_BIN}" trjconv \
        -f "${archive_dir}/${sim_name}.gro" \
        -s "${archive_dir}/${sim_name}.tpr" \
        -o "${archive_dir}/${sim_name}.gro" \
        -ur 'rect' <<EOF
System
EOF
} >>"${log_file}" 2>&1

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
        # if tpr file does not exist, create it
        if [[ ! -f "${sim_name}.tpr" ]]; then
            echo "DEBUG: Creating tpr file"
            # copy output files from NVT equilibration
            cp -np "${previous_archive_dir}/${previous_sim_name}.gro" "${previous_sim_name}.gro" || exit 1

            # replace temperature and pressure in mdp file
            cp "${mdp_file_prod}" "${sim_name}.mdp" || exit 1
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
            if [[ "${VACUUM}" == 'True' ]]; then
                sed -i 's/^ewald-geometry .*/ewald-geometry            = 3dc/g' "${sim_name}.mdp" || exit 1
                sed -i 's/^pbc .*/pbc                       = xy/g' "${sim_name}.mdp" || exit 1
                sed -i 's/^nwall .*/nwall                     = 2/g' "${sim_name}.mdp" || exit 1
                if [[ "${N_SLABS}" -eq 2 ]]; then
                    sed -i 's/^wall-atomtype             = WR WL.*/wall-atomtype             = WR WR/g' "${sim_name}.mdp" || exit 1
                fi
            fi

            # copy plumed file
            cp "${dat_file}" "plumed.dat" || exit 1
            sed -i 's/{LOWER_WALL_HEIGHT}/'"${PE_WALL_MIN}"'/g' "plumed.dat" || exit 1
            sed -i 's/{UPPER_WALL_HEIGHT}/'"${PE_WALL_MAX_EQBM}"'/g' "plumed.dat" || exit 1
            sed -i 's/{WALL_OFFSET}/'"${ATOM_OFFSET}"'/g' "plumed.dat" || exit 1
            sed -i 's/{ATOM_REFERENCE}/'"${ATOM_REFERENCE}"'/g' "plumed.dat" || exit 1
            if [[ "${N_CALCIUM}" -eq '0' ]]; then
                sed -i 's/NDX_GROUP=Aqueous_Calcium/NDX_GROUP=Crystal_Top_Surface_Calcium/g' "plumed.dat" || exit 1
            fi

            # make tpr file
            "${GMX_BIN}" -nocopyright grompp \
                -f "${sim_name}.mdp" \
                -c "${previous_sim_name}.gro" \
                -r "${previous_sim_name}.gro" \
                -n "index.ndx" \
                -p "topol.top" \
                -o "${sim_name}.tpr"
            rm "${previous_sim_name}.gro" || exit 1

        else
            echo "DEBUG: Using existing tpr file"
            # activate restart in plumed file
            sed -i 's/#RESTART/RESTART/g' "plumed.dat" || exit 1
        fi

        # run production equilibration
        # shellcheck disable=SC2086
        "${GMX_BIN}" -nocopyright mdrun -v \
            -deffnm "${sim_name}" -cpi "${sim_name}.cpt" \
            -plumed "plumed.dat" \
            ${GMX_CPU_ARGS} ${GMX_GPU_ARGS} || exit 1

        # convert final xtc frame to pdb file
        "${GMX_BIN}" -nocopyright trjconv \
            -f "${sim_name}.xtc" \
            -s "${sim_name}.tpr" \
            -o "${sim_name}.pdb" \
            -pbc 'mol' -ur 'tric' -conect \
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
            "${GMX_BIN}" -nocopyright energy \
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
        rm -f ./*.cpt || exit 1
        rm mdout.mdp || exit 1
        # move plumed files to archive directory
        cp -np "plumed.dat" -t "${archive_dir}/" || exit 1
        rm ./*.dat || exit 1
        cp -np ./*.data -t "${archive_dir}/" || true
        rm ./*.data || true
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

        # delete all backup files
        find . -type f -name '#*#' -delete || true
    } >>"${log_file}" 2>&1
fi

echo "CRITICAL: Finished system equilibration"
echo "INFO: Finished system equilibration at $(date)"

# end time
end_time="$(date +%s)"

# print runtime in hours:minutes:seconds
runtime_seconds="$((end_time - start_time))"
runtime_hours="$((runtime_seconds / 3600))"
runtime_minutes="$((runtime_seconds % 3600 / 60))"
runtime_seconds="$((runtime_seconds % 60))"
echo "INFO: Runtime: ${runtime_hours}:${runtime_minutes}:${runtime_seconds}"
{
    echo "INFO: Runtime: ${runtime_hours}:${runtime_minutes}:${runtime_seconds}"
} >>"${log_file}" 2>&1
