#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on January 25th, 2023

#SBATCH --job-name=1.5.0-OneOPES
#SBATCH --time=2-00:00:00

# Slurm: Node configuration
#SBATCH --partition=all --qos=dow --account=dow
#SBATCH --nodes=1 --ntasks-per-node=32 --mem=4G
#SBATCH --gres=gpu:2 --gpu-bind=closest

# Slurm: Runtime I/O
#SBATCH --mail-user=slurm.notifications@gmail.com --mail-type=BEGIN,END,FAIL
#SBATCH --output=logs/jobid_%j-node_%N-%x.log --error=logs/jobid_%j-node_%N-%x.log

# built-in shell options
set -o errexit # exit when a command fails
set -o nounset # exit when script tries to use undeclared variables

# simulation path variables
proj_base_dir="$(pwd)/.."
scripts_dir="${proj_base_dir}/scripts"
params_dir="${proj_base_dir}/submission/input/1-model-system"

input_globals=(
    # '4.0_16PAA_0Ca_104calcite_9nm_crystal_10nm_height.sh'
    '5.0_16PAAn_0Ca_104calcite_9nm_crystal_10nm_height.sh'
    # '6.0_16PVAc_0Ca_104calcite_9nm_crystal_10nm_height.sh'
    # '7.0_16PVOH_0Ca_104calcite_9nm_crystal_10nm_height.sh'
)

# start script
date_time=$(date +"%Y-%m-%d %T")
echo "START: ${date_time}"

parallel --link --keep-order --ungroup --halt-on-error '2' --jobs '1' \
    "${scripts_dir}/run.sh" "${params_dir}/{1}" --one-opes \
    ::: "${input_globals[@]}"

# end script
date_time=$(date +"%Y-%m-%d %T")
echo "END: ${date_time}"
