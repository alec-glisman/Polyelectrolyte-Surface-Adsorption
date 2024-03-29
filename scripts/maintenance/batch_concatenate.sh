#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2024-03-29
# Usage      : ./batch_concatenate.sh

# built-in shell options
set -o errexit  # exit when a command fails. Add || true to commands allowed to fail
set -o nounset  # exit when script tries to use undeclared variables
set -o pipefail # exit when a command in a pipe fails

# #######################################################################################
# Find Inputs ###########################################################################
# #######################################################################################

input_base_dir="/nfs/zeal_nas/home_mount/aglisman/GitHub/Polyelectrolyte-Surface-Adsorption/data_archive/6_single_chain_binding"
input_append_dir="3-sampling-opes-one/replica_00"
sim_name="prod_opes_one_multicv"

# input dirs is all subdirectories of input_base_dir
mapfile -t input_dirs < <(find "${input_base_dir}" -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 -I {} basename {} | sort)
input_dirs=("${input_dirs[@]/%//${input_append_dir}}")
input_dirs=("${input_dirs[@]/#/${input_base_dir}/}")

# get dir of this file
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# #######################################################################################
# Call script in parallel ###############################################################
# #######################################################################################

# print all input directories
echo "INFO: Found ${#input_dirs[@]} input directories"
for idx in "${!input_dirs[@]}"; do
    echo "DEBUG: ${idx}: ${input_dirs[idx]}"
done

parallel --link --keep-order --ungroup --halt-on-error '2' --jobs '4' --joblog 'concatenate_sim.log' \
    "${script_dir}/concatenate_sim.sh" "{1}" "${sim_name}" \
    ::: "${input_dirs[@]}"
