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

# Gromacs files
mdp_path="${project_path}/parameters/mdp/molecular-dynamics"
mdp_file_nvt="${mdp_path}/nvt_eqbm_10ns.mdp"
mdp_file_npt="${mdp_path}/npt_eqbm_10ns.mdp"
if [[ "${PRODUCTION_ENSEMBLE^^}" == "NVT" ]]; then
    mdp_file_prod="${mdp_path}/nvt_eqbm_10ns.mdp"
elif [[ "${PRODUCTION_ENSEMBLE^^}" == "NPT" ]]; then
    mdp_file_prod="${mdp_path}/npt_eqbm_10ns.mdp"
else
    echo "ERROR: PRODUCTION_ENSEMBLE must be set to NVT or NPT"
    exit 1
fi

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
sim_name="nvt_eqbm"

# check if "1-nvt/nvt_eqbm.gro" exists
if [[ -f "1-nvt/${sim_name}.gro" ]]; then
    echo "WARNING: 1-nvt/nvt_eqbm.gro does not exist"
    echo "INFO: Skipping NVT equilibration"
else
    {
        # copy output files from initialization
        prev_dir_base="../1-energy-minimization/2-output"
        cp -p "${prev_dir_base}/system.gro" "${previous_sim_name}.gro" || exit 1
        cp -p "${prev_dir_base}/topol.top" "topol.top" || exit 1
        cp -p "${prev_dir_base}/index.ndx" "index.ndx" || exit 1

        # replace temperature in mdp file
        cp "${mdp_file_nvt}" "${sim_name}.mdp" || exit 1
        sed -i "s/ref-t                     = 300/ref-t                     = ${TEMPERATURE_K}/g" "nvt_eqbm.mdp" || exit 1

        # make tpr file for NVT equilibration
        "${GMX_BIN}" -quiet -nocopyright grompp \
            -f "${sim_name}.mdp" \
            -c "${previous_sim_name}.gro" \
            -p "topol.top" \
            -o "${sim_name}.tpr" \
            -maxwarn '1'

        # run NVT equilibration
        "${MPI_BIN}" -np '1' \
            --map-by "ppr:1:node:PE=${CPU_THREADS}" \
            --use-hwthread-cpus --bind-to 'hwthread' \
            "${GMX_BIN}" -quiet -nocopyright mdrun -v \
            -deffnm "${sim_name}" \
            -pin on -pinoffset "${PIN_OFFSET}" -pinstride 1 -ntomp "${CPU_THREADS}" \
            -gpu_id "${GPU_IDS}" || exit 1

        # plot system temperature over time
        "${GMX_BIN}" -quiet -nocopyright energy \
            -f "${sim_name}.edr" \
            -o "temperature.xvg" <<EOF
Temperature
0
EOF
        # convert xvg to png
        gracebat -nxy "temperature.xvg" \
            -hdevice "PNG" \
            -autoscale "xy" \
            -printfile "temperature.png" \
            -fixed "3840" "2160"

        # copy output files to 1-nvt
        mkdir -p "1-nvt"
        cp -p "${sim_name}."* -t "1-nvt/" || exit 1
        cp -p "temperature."* -t "1-nvt/" || exit 1
        rm "${sim_name}."* || exit 1
        cp -p "1-nvt/${sim_name}.gro" "${sim_name}.gro" || exit 1
    } >>"${log_file}" 2>&1
fi

# #######################################################################################
# NPT equilibration #####################################################################
# #######################################################################################
echo "INFO: Starting NPT equilibration"
previous_sim_name="${sim_name}"
sim_name="npt_eqbm"

# TODO: Use sed to replace the following variables in the mdp file:
#       - TEMP
#       - PRESSURE

# #######################################################################################
# Production equilibration ##############################################################
# #######################################################################################
echo "INFO: Starting production equilibration"
previous_sim_name="${sim_name}"
sim_name="prod_eqbm"

# #######################################################################################
# Clean up ##############################################################################
# #######################################################################################
echo "INFO: Cleaning up"

echo "CRITICAL: Finished system equilibration"
