#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Created by Alec Glisman (GitHub: @alec-glisman) on February 2nd, 2023
#

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# data I/O directories
remote_address='aglisman@zeal.caltech.edu'
remote_dir='/nfs/zeal_nas/home_mount/aglisman/GitHub/Polyelectrolyte-Surface-Adsorption/data_archive/6_single_chain_binding/cleaned'
local_dir='/media/aglisman/Data/Single-Chain-Adsorption'
patterns=('3-sampling-opes-one/replica_00/2-concatenated' '3-sampling-opes-one/replica_00/4-polymer' '3-sampling-opes-one/analysis/combined')

# ########################################################################## #
# Move data to new directory with rsync                                      #
# ########################################################################## #
echo "INFO) Moving files to new directory"
echo "DEBUG) Destination directory: ${local_dir}"

# find all directories on the remote server that match the pattern
echo "INFO) Listing files in source directory"
remote_files=""
for pattern in "${patterns[@]}"; do
    echo "DEBUG) Searching for files matching pattern: ${pattern}"
    files=$(ssh "${remote_address}" 'find /nfs/zeal_nas/home_mount/aglisman/GitHub/Polyelectrolyte-Surface-Adsorption/data_archive/6_single_chain_binding/cleaned -type f' | grep "${pattern}")
    remote_files+="${files}"
done

remote_files=$(echo "${remote_files}" | grep -v '\.lock' | grep -v '\.npz')
remote_files=$(echo "${remote_files}" | sort | uniq)

# remove remote dir path from remote files
remote_files=$(echo "${remote_files}" | sed "s|${remote_dir}/||g")
mapfile -t remote_files <<<"${remote_files}"

for file in "${remote_files[@]}"; do
    echo "DEBUG) ${file}"
done

# prompt user to accept or reject moving files
read -p "Do you want to move files from the source to the destination directory? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "INFO) Not moving files"
else
    echo "INFO) Moving files in parallel"
    parallel --jobs 24 --bar --halt-on-error '0' --joblog 'move_data_from_remote_to_local.log' \
        rsync --archive --progress --verbose --human-readable --mkpath "${remote_address}:${remote_dir}/{1}" "${local_dir}/{1}" \
        ::: "${remote_files[@]}"
fi

echo "INFO) Done"
