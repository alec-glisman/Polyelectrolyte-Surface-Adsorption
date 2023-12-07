#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-08-30
# Description: Script to set generic global variables pertaining to the node
#              hardware and software.
# Notes      : Script should only be called from the main run.sh script.

# ##############################################################################
# Set software and hardware ####################################################
# ##############################################################################

# set paths to executables
hostname="$(hostname -s)"
if [[ "${hostname}" == "zeal" || "${hostname}" == "node"* ]]; then
    module_root="/nfs/zeal_nas/home_mount/modules"
    compilers="gcc_12.3.0-cuda_12.2.128"
    mpi_root="${module_root}/openmpi_4.1.5-${compilers}"
    plumed_root="${module_root}/plumed_mpi_2.9.0-${compilers}"
    gmx_root="${module_root}/gromacs_mpi_2023-plumed_mpi_2.9.0-${compilers}"

    MPI_BIN="${mpi_root}/bin/mpiexec"
    PLUMED_BIN="${plumed_root}/bin/plumed"
    PLUMED_KERNEL="${plumed_root}/lib/libplumedKernel.so"
    GMX_BIN="${gmx_root}/bin/gmx_mpi"

    PATH="${plumed_root}/bin:${gmx_root}/bin:${mpi_root}/bin:${PATH}"
    LD_LIBRARY_PATH="${plumed_root}/lib:${gmx_root}/lib:${LD_LIBRARY_PATH}"
    # shellcheck disable=SC2139
    alias plumed="${PLUMED_BIN}/bin/plumed"

elif [[ "${hostname}" == "desktop" ]]; then
    module_root="/home/aglisman/software"
    compilers="gcc_12.3.0-cuda_12.0.140"
    mpi_root="/usr"
    plumed_root="${module_root}/plumed_mpi_2.9.0-${compilers}"
    gmx_root="${module_root}/gromacs_mpi_2023-plumed_mpi_2.9.0-${compilers}"

    MPI_BIN="${mpi_root}/bin/mpiexec"
    PLUMED_BIN="${plumed_root}/bin/plumed"
    PLUMED_KERNEL="${plumed_root}/lib/libplumedKernel.so"
    GMX_BIN="${gmx_root}/bin/gmx_mpi"

    PATH="${plumed_root}/bin:${gmx_root}/bin:${mpi_root}/bin:${PATH}"
    LD_LIBRARY_PATH="${plumed_root}/lib:${gmx_root}/lib:${LD_LIBRARY_PATH}"
    # shellcheck disable=SC2139
    alias plumed="${PLUMED_BIN}/bin/plumed"

else
    MPI_BIN="mpirun"
    GMX_BIN="gmx_mpi"
    PLUMED_BIN="plumed"

fi

export MPI_BIN
export PLUMED_BIN
export PLUMED_KERNEL
export GMX_BIN
export PATH


# Use SLURM environment variables if available
if [[ -n "${SLURM_NTASKS+x}" ]] && [[ "${CPU_THREADS}" != "-1" ]]; then
    export CPU_THREADS="${SLURM_NTASKS}"
    export PLUMED_NUM_THREADS="${CPU_THREADS}"
fi
if [[ -n ${SLURM_GPUS+x} ]] && [[ "${GPU_IDS}" != "-1" ]]; then
    export GPU_IDS="${SLURM_GPUS}"
fi

# choose CPU thread options
if [[ "${CPU_THREADS}" == "-1" ]]; then
    GMX_CPU_ARGS='-pin on -pinstride 1'
elif [[ "${PIN_OFFSET}" == "-1" ]]; then
    GMX_CPU_ARGS="-nt ${CPU_THREADS} -pin on -pinstride 1"
else
    GMX_CPU_ARGS="-nt ${CPU_THREADS} -pin on -pinoffset ${PIN_OFFSET} -pinstride 1"
fi
export GMX_CPU_ARGS

# choose GPU options
if [[ "${GPU_IDS}" = "-1" ]]; then
    GMX_GPU_ARGS=''
else
    GMX_GPU_ARGS="-gpu_id ${GPU_IDS}"
fi
export GMX_GPU_ARGS

# define number of computational nodes
# shellcheck disable=SC2236
if [[ ! -n "${SLURM_JOB_NUM_NODES+x}" ]]; then
    export SLURM_JOB_NUM_NODES='1'
fi

# REVIEW: Allow direct GPU communication for Gromacs
# export GMX_ENABLE_DIRECT_GPU_COMM='1'

# Hamiltonian replica exchange defaults
n_threads_per_node="$(grep -c ^processor /proc/cpuinfo)"
export HREMD_N_SIM_PER_NODE=$(((HREMD_N_REPLICA + SLURM_JOB_NUM_NODES - 1) / SLURM_JOB_NUM_NODES)) # number of replicas run per node (ceil division)
export HREMD_N_THREAD_PER_SIM=$((n_threads_per_node / HREMD_N_SIM_PER_NODE))                       # number of CPU threads per replica (floor division)

# OneOPES replica exchange defaults
export ONEOPES_N_SIM_PER_NODE=$(((ONEOPES_N_REPLICA + SLURM_JOB_NUM_NODES - 1) / SLURM_JOB_NUM_NODES)) # number of replicas run per node (ceil division)
export ONEOPES_N_THREAD_PER_SIM=$((n_threads_per_node / ONEOPES_N_SIM_PER_NODE))                       # number of CPU threads per replica (floor division)
