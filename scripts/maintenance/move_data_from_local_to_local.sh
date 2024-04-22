#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Created by Alec Glisman (GitHub: @alec-glisman) on February 2nd, 2023
#

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# data I/O directories
source_dir='/nfs/zeal_nas/home_mount/aglisman/GitHub/Polyelectrolyte-Surface-Adsorption/data_archive'
dest_dir='/nfs/zeal_nas/data_mount/aglisman-data/1-electronic-continuum-correction/7-single-chain-surface-binding'

# ########################################################################## #
# Move data to new directory with rsync                                      #
# ########################################################################## #

# prompt user to accept or reject moving files
echo "INFO) Moving files to new directory"
echo "DEBUG) Source directory: ${source_dir}"
echo "DEBUG) Destination directory: ${dest_dir}"
read -p "Do you want to move files from the source to the destination directory? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "INFO) Not moving files"
else
    echo "INFO) Moving files"
    rsync --verbose --archive --progress --human-readable --relative --stats \
    "${source_dir}/." "${dest_dir}/"
fi

echo "INFO) Done"
