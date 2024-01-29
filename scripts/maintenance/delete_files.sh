#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Created by Alec Glisman (GitHub: @alec-glisman) on February 2nd, 2023
#

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# idx is the input directory index
idx="${1}"

input_dirs_relative=(
    'data_archive/1_model_systems/1.4.0-calcite-104surface-9nm_surface-10nm_vertical-1chain-PAcr-16mer-0Crb-0Ca-16Na-0Cl-300K-1bar-NVT'
)
input_dir_base='/nfs/zeal_nas/home_mount/aglisman/GitHub/Polyelectrolyte-Surface-Adsorption'
input_dir="${input_dir_base}/${input_dirs_relative[${idx}]}"

# find all .trr files in input directories and convert to array
trr_files="$(find "${input_dir}" -type f -name '*.trr')"
mapfile -t trr_files <<<"${trr_files}"
# find all .xtc files in input directories and convert to array
xtc_files="$(find "${input_dir}" -type f -name '*.xtc')"
mapfile -t xtc_files <<<"${xtc_files}"

# remove items in trr_files containing patterns
patterns=(
    '*/replica_00/*'
    '*/3-sampling-md/*'
    '*/3-sampling-metad/*'
)
for pattern in "${patterns[@]}"; do
    trr_files=("${trr_files[@]/${pattern}/}")
    xtc_files=("${xtc_files[@]/${pattern}/}")
done

# remove all empty elements
for i in "${!trr_files[@]}"; do
    if [[ -z "${trr_files[i]}" ]]; then
        unset 'trr_files[i]'
    fi
done
for i in "${!xtc_files[@]}"; do
    if [[ -z "${xtc_files[i]}" ]]; then
        unset 'xtc_files[i]'
    fi
done

# ANCHOR: Find all backup files
backup_files="$(find "${input_dir}" -type f -name '#*#')"
mapfile -t backup_files <<<"${backup_files}"
patterns=(
    '*log*'
)
for pattern in "${patterns[@]}"; do
    backup_files=("${backup_files[@]/${pattern}/}")
done
# remove all empty elements from backup_files
for i in "${!backup_files[@]}"; do
    if [[ -z "${backup_files[i]}" ]]; then
        unset 'backup_files[i]'
    fi
done

# ANCHOR: Delete all trr, xtc, and backup files
if [[ ! "${#trr_files[@]}" -eq 0 ]]; then
    echo "Deleting .trr files..."
    parallel --keep-order --ungroup --jobs '32' --eta --halt-on-error '2' \
        rm --verbose "{1}" \
        ::: "${trr_files[@]}"
else
    echo "No .trr files found."
fi

if [[ ! "${#xtc_files[@]}" -eq 0 ]]; then
    echo "Deleting .xtc files..."
    parallel --keep-order --ungroup --jobs '32' --eta --halt-on-error '2' \
        rm --verbose "{1}" \
        ::: "${xtc_files[@]}"
else
    echo "No .xtc files found."
fi

if [[ ! "${#backup_files[@]}" -eq 0 ]]; then
    echo "Deleting backup files..."
    parallel --keep-order --ungroup --jobs '32' --eta --halt-on-error '2' \
        rm --verbose "{1}" \
        ::: "${backup_files[@]}"
else
    echo "No Gromacs backup files found."
fi
