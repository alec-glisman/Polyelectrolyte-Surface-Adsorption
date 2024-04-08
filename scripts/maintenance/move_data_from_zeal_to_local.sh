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
local_dir='/Volumes/ExFat/single_chain_binding'
pattern='*/2-concatenated/*'

# ########################################################################## #
# Move data to new directory with rsync                                      #
# ########################################################################## #

# prompt user to accept or reject moving files
echo "INFO) Moving files to new directory"
echo "DEBUG) Source directory: ${remote_address}:${remote_dir}"
echo "DEBUG) Destination directory: ${local_dir}"
read -p "Do you want to move files from the source to the destination directory? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "INFO) Not moving files"
else
    echo "INFO) Moving files"
    rsync --archive --verbose --progress --human-readable --dry-run \
    --include="${pattern}" --exclude="*" \
    "${remote_address}:${remote_dir}/" "${local_dir}/"
fi

echo "INFO) Done"
