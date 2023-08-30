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
mdp_file_nvt="${project_path}/nvt_eqbm_10ns.mdp"
mdp_file_npt="${project_path}/npt_eqbm_10ns.mdp"
if [[ "${PRODUCTION_ENSEMBLE^^}" == "NVT" ]]; then
    mdp_file_prod="${project_path}/nvt_eqbm_10ns.mdp"
elif [[ "${PRODUCTION_ENSEMBLE^^}" == "NPT" ]]; then
    mdp_file_prod="${project_path}/npt_eqbm_10ns.mdp"
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

# see if "2-output/system.gro" exists
if [[ -f "4-output/system.gro" ]]; then
    echo "WARNING: 4-output/system.gro already exists"
    echo "INFO: Exiting script"
    exit 0
fi

# #######################################################################################
# NVT equilibration #####################################################################
# #######################################################################################
echo "INFO: Starting NVT equilibration"

# TODO: Use sed to replace the following variables in the mdp file:
#       - TEMP
#       - PRESSURE

# #######################################################################################
# NPT equilibration #####################################################################
# #######################################################################################
echo "INFO: Starting NPT equilibration"

# #######################################################################################
# Production equilibration ##############################################################
# #######################################################################################
echo "INFO: Starting production equilibration"

# #######################################################################################
# Clean up ##############################################################################
# #######################################################################################
echo "INFO: Cleaning up"

echo "CRITICAL: Finished system equilibration"
