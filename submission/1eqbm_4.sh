#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on January 25th, 2023

#SBATCH --job-name=SysInit
#SBATCH --time=2-00:00:00

# Slurm: Node configuration
#SBATCH --partition=all --qos=dow --account=dow
#SBATCH --nodes=1 --ntasks-per-node=16 --mem=4G
#SBATCH --gres=gpu:1 --gpu-bind=closest

# Slurm: Runtime I/O
#SBATCH --mail-user=slurm.notifications@gmail.com --mail-type=BEGIN,END,FAIL
#SBATCH --output=logs/jobid_%j-node_%N-%x.log --error=logs/jobid_%j-node_%N-%x.log

# built-in shell options
set -o errexit # exit when a command fails
set -o nounset # exit when script tries to use undeclared variables

# simulation path variables
proj_base_dir="$(pwd)/.."
scripts_dir="${proj_base_dir}/scripts"
params_dir="${proj_base_dir}/submission/input/4-test-systems"

# input globals is an array of all files in the params_dir stripped of the params_dir path
input_globals=()
while IFS= read -r -d '' file; do
    input_globals+=("${file##*/}")
done < <(find "${params_dir}" -type f -name "*.sh" -print0)
echo "${input_globals[@]}"

# sort input globals
# shellcheck disable=SC2207
IFS=$'\n' input_globals=($(sort <<<"${input_globals[*]}"))

# start script
date_time=$(date +"%Y-%m-%d %T")
echo "START: ${date_time}"

parallel --link --keep-order --ungroup --halt-on-error '2' --jobs '1' \
    "${scripts_dir}/run.sh" "${params_dir}/{1}" --equilibrate \
    ::: "${input_globals[@]}"

# end script
date_time=$(date +"%Y-%m-%d %T")
echo "END: ${date_time}"
