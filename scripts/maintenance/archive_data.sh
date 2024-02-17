#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# Created by Alec Glisman (GitHub: @alec-glisman) on February 2nd, 2023
#

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# data I/O directories
input_dir_base='/nfs/zeal_nas/home_mount/aglisman/GitHub/Polyelectrolyte-Surface-Adsorption/data'
output_dir_base='/nfs/zeal_nas/data_mount/aglisman-data/1-electronic-continuum-correction/6-surface-study-test-calculations'

# ########################################################################## #
# Find and delete files                                                      #
# ########################################################################## #
find_and_delete_files() {
    # args
    local file_type=$1
    local patterns=("${@:2}")

    # find files
    echo "INFO) Finding ${file_type} files"
    local files
    files="$(find "${input_dir_base}" -type f -name "*${file_type}" -mtime +1)"
    mapfile -t files <<<"${files}"

    # exclude files containing excluded patterns
    local len="${#files[@]}"
    for pattern in "${patterns[@]}"; do
        files=("${files[@]/${pattern}/}")
    done
    for i in "${!files[@]}"; do
        if [[ -z "${files[i]}" ]]; then
            unset 'files[i]'
        fi
    done
    echo "DEBUG) Removed $((len - ${#files[@]})) ${file_type} files for containing excluded patterns"

    # list files to be deleted
    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "WARNING) No ${file_type} files found"
        return
    fi
    echo "INFO) Here are the ${file_type} files to be deleted (total: ${#files[@]}):"
    for file in "${files[@]}"; do
        # only display file name and 3 parent directories
        file_short="${file/${input_dir_base}/}"
        for i in {1..2}; do
            file_short="${file_short#*/}"
        done
        echo " - ${file_short}"
    done

    # prompt user to delete files
    read -p "Do you want to delete these files? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "INFO) Deleting ${file_type} files"
        parallel --keep-order --jobs '32' --eta --halt-on-error '2' --joblog "delete${file_type}.log" \
            rm --verbose "{1}" \
            ::: "${files[@]}"
    else
        echo "INFO) Not deleting ${file_type} files"
    fi
}

# Backup files
find_and_delete_files '#*#' '*log*'
# TRR files
find_and_delete_files '.trr' '*/replica_00/*' '*/3-sampling-md/*' '*/3-sampling-metad/*'
# XTC files
find_and_delete_files '.xtc' '*/replica_00/*' '*/3-sampling-*/*'

# ########################################################################## #
# Down-sample trajectory files that are not in pattern                       #
# ########################################################################## #
downsample() {
    local input_file="${1}"
    local extension="${input_file##*.}"
    local output_file="${input_file%.*}_downsampled.${extension}"
    # down-sample trajectory file
    gmx_mpi trjconv -f "${input_file}" -o "${output_file}" -skip '10' <<EOF
System
EOF
    # remove original file
    rm --verbose "${input_file}"
}
export -f downsample

down_sample_files() {
    # args
    local file_type=$1
    local patterns=("${@:2}")

    # find files
    echo "INFO) Finding ${file_type} files"
    local files
    files="$(find "${input_dir_base}" -type f -name "*${file_type}" -mtime +1)"
    mapfile -t files <<<"${files}"

    # exclude files containing excluded patterns
    local len="${#files[@]}"
    for pattern in "${patterns[@]}"; do
        files=("${files[@]/${pattern}/}")
    done
    for i in "${!files[@]}"; do
        if [[ -z "${files[i]}" ]]; then
            unset 'files[i]'
        fi
    done
    echo "DEBUG) Removed $((len - ${#files[@]})) ${file_type} files for containing excluded patterns"

    # list files to be down-sampled
    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "WARNING) No ${file_type} files found"
        return
    fi
    echo "INFO) Here are the ${file_type} files to be down-sampled (total: ${#files[@]}):"
    for file in "${files[@]}"; do
        # only display file name and 3 parent directories
        file_short="${file/${input_dir_base}/}"
        for i in {1..1}; do
            file_short="${file_short#*/}"
        done
        echo " - ${file_short}"
    done

    # prompt user to down-sample files
    read -p "Do you want to down-sample these files? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "INFO) Down-sampling ${file_type} files"
        parallel --keep-order --jobs '30' --eta --halt-on-error '2' --joblog "downsample${file_type}.log" \
            downsample "{1}" \
            ::: "${files[@]}"
    else
        echo "INFO) Not down-sampling ${file_type} files"
    fi

}

# Down-sample TRR files
down_sample_files '.trr' '*/replica_00/*' '*/3-sampling-md/*' '*/3-sampling-metad/*' '*_downsampled*' '*6.2.4*' '*6.4.0*' '*6.4.2*' '*6.5.0*' '*6.5.1*' '*6.5.2*' '*6.5.3*' '*6.5.4*'
# Down-sample XTC files
down_sample_files '.xtc' '*/replica_00/*' '*/3-sampling-md/*' '*/3-sampling-metad/*' '*_downsampled*' '*6.2.4*' '*6.4.0*' '*6.4.2*' '*6.5.0*' '*6.5.1*' '*6.5.2*' '*6.5.3*' '*6.5.4*'

# ########################################################################## #
# Output file information                                                    #
# ########################################################################## #

echo "INFO) Output file information"
echo "INFO) Source directory: ${input_dir_base}"
echo "INFO) Size of source directory: $(\du -sh "${input_dir_base}")"
dust "${input_dir_base}"

# ########################################################################## #
# Move data to new directory with rsync                                      #
# ########################################################################## #
# move files
echo "INFO) Moving files to new directory"

# prompt user to accept or reject moving files
echo "DEBUG) Source directory: ${input_dir_base}"
echo "DEBUG) Destination directory: ${output_dir_base}"
read -p "Do you want to move files from the source to the destination directory? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "INFO) Not moving files"
    exit 0
fi

# move files
echo "INFO) Moving files"
rsync --archive --verbose --progress --human-readable --remove-source-files \
    "${input_dir_base}/" "${output_dir_base}/"

echo "INFO) Done"
