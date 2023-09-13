#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-08-30
# Description: Script to set global variables and preferences for the simulation
#              and run the simulation.
# Usage      : ./run.sh [global_preferences] [simulation_preferences]

# built-in shell options
set -o errexit  # exit when a command fails. Add || true to commands allowed to fail
set -o nounset  # exit when script tries to use undeclared variables
set -o pipefail # exit when a command in a pipe fails

package="run.sh" # name of this script

# ##############################################################################
# Input parsing ################################################################
# ##############################################################################

# input checking
if [[ $# -lt 2 ]]; then
    echo "ERROR: Too few arguments."
    echo "Usage: ${package} [global_preferences] [simulation_preferences]"
    echo "Use '${package} --help' for more information."
    exit 1
fi

# global preferences file
global_preferences="${1}"

# simulation method flags
flag_initialization=false
flag_equilibration=false
flag_production=false
flag_sampling_md=false
flag_sampling_opes_explore=false

# action flags
flag_archive=false

# remove global preferences from command line arguments
shift

# parse command line arguments
for arg in "$@"; do
    case "${arg}" in
    -i | --initialize)
        flag_initialization=true
        ;;
    -e | --equilibrate)
        flag_equilibration=true
        ;;
    -p | --production)
        flag_production=true
        ;;
    -a | --all)
        flag_initialization=true
        flag_equilibration=true
        flag_production=true
        ;;
    -m | --md)
        flag_sampling_md=true
        ;;
    -o | --opes)
        flag_sampling_opes_explore=true
        ;;
    -r | --archive)
        flag_archive=true
        ;;
    -h | --help)
        echo "Usage: ${package} [global_preferences] [simulation_preferences]"
        echo ""
        echo "Simulation preferences (methods):"
        echo "  -i, --initialize    Initialize the simulation."
        echo "  -e, --equilibrate   Equilibrate the simulation."
        echo "  -p, --production    Run the production simulation."
        echo "  -a, --all           Run all simulations."
        echo ""
        echo "Production sampling methods:"
        echo "  -m, --md            Molecular dynamics (unbiased)."
        echo "  -o, --opes          OPES Explore (biased)."
        echo ""
        echo "Other:"
        echo "  -r, --archive       Archive the simulation."
        echo "  -h, --help          Display this help message."
        echo ""
        exit 0
        ;;
    *)
        echo "ERROR: Unrecognized argument: ${arg}"
        echo "Usage: ${package} [global_preferences] [simulation_preferences] [sampling]"
        exit 1
        ;;
    esac
done

# check that at least one simulation method was selected
if [[ "${flag_initialization}" = false ]] && [[ "${flag_equilibration}" = false ]] && [[ "${flag_production}" = false ]]; then
    echo "ERROR: No simulation methods selected."
    echo "Usage: ${package} [global_preferences] [simulation_preferences]"
    echo "Use '${package} --help' for more information."
    exit 1
fi

# check that if production was selected, at least one sampling method was selected
if [[ "${flag_production}" = true ]] && [[ "${flag_sampling_md}" = false ]]; then
    echo "ERROR: No production sampling methods selected."
    echo "Usage: ${package} [global_preferences] [simulation_preferences]"
    echo "Use '${package} --help' for more information."
    exit 1
fi

# ##############################################################################
# Load input preferences #######################################################
# ##############################################################################

# find path to this script
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
project_path="${script_path}/.."

# load global preferences
# shellcheck source=../submission/input/0-setup/0_large_box_pe.sh
source "${global_preferences}"
# shellcheck source=variable/system.sh
source "${project_path}/scripts/variable/system.sh"
# shellcheck source=variable/node.sh
source "${project_path}/scripts/variable/node.sh"

# create simulation directory and move into it
mkdir -p "${project_path}/data/${TAG}"
cd "${project_path}/data/${TAG}" || exit 1

# ##############################################################################
# Run simulation methods #######################################################
# ##############################################################################

# initialize simulation
if [[ "${flag_initialization}" = true ]]; then
    echo "Initializing simulation..."
    "${project_path}/scripts/method/initialization.sh"
fi

# equilibrate simulation
if [[ "${flag_equilibration}" = true ]]; then
    echo "Equilibrating simulation..."
    "${project_path}/scripts/method/equilibration.sh"
fi

# run production simulation
if [[ "${flag_production}" = true ]]; then
    echo "INFO: Archiving simulation: ${flag_archive}"
    export FLAG_ARCHIVE="${flag_archive}"

    # find walltime remaining
    # shellcheck source=variable/slurm.sh
    source "${project_path}/scripts/variable/slurm.sh"
    echo "INFO: WALLTIME_HOURS: ${WALLTIME_HOURS}"

    # molecular dynamics
    if [[ "${flag_sampling_md}" = true ]]; then
        echo "Sampling molecular dynamics..."
        "${project_path}/scripts/method/sampling_md.sh"
    fi

    # OPES explore
    if [[ "${flag_sampling_opes_explore}" = true ]]; then
        echo "Sampling OPES explore..."
        "${project_path}/scripts/method/sampling_opes_explore.sh"
    fi
fi

# ##############################################################################
# End ##########################################################################
# ##############################################################################

echo "INFO: ${package} completed successfully."
