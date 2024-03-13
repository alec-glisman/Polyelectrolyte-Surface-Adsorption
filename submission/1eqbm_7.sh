#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on January 25th, 2023

#SBATCH --time=2-00:00:00

# Slurm: Node configuration
#SBATCH --partition=all --qos=dow --account=dow
#SBATCH --nodes=1 --ntasks-per-node=16 --mem=4G
#SBATCH --gres=gpu:1 --gpu-bind=closest

# Slurm: Runtime I/O
#SBATCH --mail-user=slurm.notifications@gmail.com --mail-type=BEGIN,END,FAIL
#SBATCH --output=logs/jobid_%j-node_%N-%x.log --error=logs/jobid_%j-node_%N-%x.log

# REVIEW: find all input files with command:
# find . -maxdepth 1 -type f -print0 | xargs -0 -I {} echo "'{}'" | sed "s|'./|'|g" | sort

# built-in shell options
set -o errexit # exit when a command fails
set -o nounset # exit when script tries to use undeclared variables

# simulation path variables
proj_base_dir="$(pwd)/.."
scripts_dir="${proj_base_dir}/scripts"
params_dir="${proj_base_dir}/submission/input/7-vacuum-systems"
mapfile -t input_globals < <(find "${params_dir}" -mindepth 1 -maxdepth 1 -type f -print0 | xargs -0 -I {} basename {} | sort)

echo "INFO: Found ${#input_globals[@]} input global directories"
for idx in "${!input_globals[@]}"; do
    echo "DEBUG: ${idx}: ${input_globals[idx]}"
done

# argument parsing
# 1st argument: input global indices to run
idxs=()
if [ $# -eq 0 ]; then
    mapfile -t idxs < <(seq 0 $((${#input_globals[@]} - 1)))
else
    idxs=("$@")
fi

# check if input indices are valid
for idx in "${idxs[@]}"; do
    if [ "${idx}" -lt 0 ] || [ "${idx}" -ge ${#input_globals[@]} ]; then
        echo "ERROR: invalid input index: ${idx}"
        exit 1
    fi
done

# filter input globals
input_globals=("${input_globals[@]:${idxs[0]}:${#idxs[@]}}")
echo "DEBUG: Running input global directories:" "${input_globals[@]}"

# start script
date_time=$(date +"%Y-%m-%d %T")
echo "START: ${date_time}"

parallel --link --keep-order --ungroup --halt-on-error '2' --jobs '1' \
    "${scripts_dir}/run.sh" "${params_dir}/{1}" --equilibrate \
    ::: "${input_globals[@]}"

# end script
date_time=$(date +"%Y-%m-%d %T")
echo "END: ${date_time}"