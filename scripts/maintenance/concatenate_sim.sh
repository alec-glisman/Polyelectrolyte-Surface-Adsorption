#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2024-03-29
# Usage      : ./concatenate_sim.sh <sim_dir> <sim_name>

# built-in shell options
set -o errexit  # exit when a command fails. Add || true to commands allowed to fail
set -o nounset  # exit when script tries to use undeclared variables
set -o pipefail # exit when a command in a pipe fails

# #######################################################################################
# Argument Parsing ######################################################################
# #######################################################################################
if [ "$#" -ne 2 ]; then
    echo "ERROR: Illegal number of parameters"
    echo "USAGE: $0 <sim_dir> <sim_name>"
    exit 1
fi

# first argument is the simulation directory
cwd="${1}"

# second argument is the simulation name
sim_name="${2}"

# #######################################################################################
# Default Preferences ###################################################################
# #######################################################################################
# initial time with _ as separator
time_init="$(date +%Y_%m_%d_%H_%M_%S)"

# Output files
log_dir="${cwd}/logs"
log_file_concat="${log_dir}/${time_init}-2-concatenation.log"
log_file_cleanup="${log_dir}/${time_init}-3-cleanup.log"

# if gmx_mpi exists, use it, else use gmx
if command -v gmx_mpi &>/dev/null; then
    GMX_BIN="gmx_mpi"
else
    GMX_BIN="gmx"
fi

# move to working directory
cd "${cwd}" || exit 1
mkdir -p "${log_dir}"
echo "CRITICAL: Starting Concatenation for simulation ${sim_name} at directory ${cwd}"

# #######################################################################################
# Concatenate trajectories ##############################################################
# #######################################################################################
{
    echo "################################################################################"
    echo "Script: ${BASH_SOURCE[0]}"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "################################################################################"
    echo ""
} >>"${log_file_concat}" 2>&1

# rsync output files to archive directory
echo "INFO: Archiving simulation"
archive_dir="1-runs"
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

# concatenate files into single trajectory
echo "INFO: Concatenating files"
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

    # copy plumed files
    cp "${archive_dir}/"*.data "${concat_dir}/" || exit 1
} >>"${log_file_concat}" 2>&1

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

    # copy *.data files
    cp "${concat_dir}/"*.data -t "${nosol_dir}/" || exit 1
} >>"${log_file_concat}" 2>&1

# #######################################################################################
# Clean Up ##############################################################################
# #######################################################################################
echo "INFO: Cleaning up"
{
    echo "################################################################################"
    echo "Script: ${BASH_SOURCE[0]}"
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo "################################################################################"
    echo ""
} >>"${log_file_cleanup}" 2>&1

# {
#     # iterate over directories and delete backup files
#     for dir in "${archive_dir}" "${concat_dir}" "${nosol_dir}" "."; do
#         find "${dir}" -type f -name '#*#' -delete || true
#     done
# } >>"${log_file_cleanup}" 2>&1

echo "CRITICAL: Finished Concatenation for simulation ${sim_name} at directory ${cwd}"
