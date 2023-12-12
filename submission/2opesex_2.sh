#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on January 25th, 2023

#SBATCH --job-name=2-OPES-Ex
#SBATCH --time=2-00:00:00

# Slurm: Node configuration
#SBATCH --partition=all --qos=dow --account=dow
#SBATCH --nodes=1 --ntasks-per-node=24 --mem=4G
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
params_dir="${proj_base_dir}/submission/input/2-monomers"

input_globals=(
    '1.0_1PAA_0Ca_104calcite_5nm_crystal_8nm_height.sh'
    '2.0_1PAAn_0Ca_104calcite_5nm_crystal_8nm_height.sh'
    '3.0_1PVAc_0Ca_104calcite_5nm_crystal_8nm_height.sh'
    '4.0_1PVOH_0Ca_104calcite_5nm_crystal_8nm_height.sh'
)

# start script
date_time=$(date +"%Y-%m-%d %T")
echo "START: ${date_time}"

parallel --link --keep-order --ungroup --halt-on-error '2' --jobs '4' \
    "${scripts_dir}/run.sh" "${params_dir}/{1}" --all --opes-explore \
    ::: "${input_globals[@]}"

# end script
date_time=$(date +"%Y-%m-%d %T")
echo "END: ${date_time}"
