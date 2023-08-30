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
    MPI_BIN="/home/aglisman/software/openmpi_4.1.5-gcc_12.3.0-cuda_12.0.140/bin/mpiexec"
    GMX_BIN="/home/aglisman/software/gromacs_mpi_2023-plumed_mpi_2.9.0-gcc_12.3.0-cuda_12.0.140/bin/gmx_mpi"
elif [[ "${hostname}" == "desktop" ]]; then
    MPI_BIN="/usr/bin/mpiexec"
    GMX_BIN="/nfs/zeal_nas/home_mount/modules/gromacs_mpi_2023-plumed_mpi_2.9.0-gcc_self_12.3.0-cuda_12.2.128/bin/gmx_mpi"
else
    MPI_BIN="mpirun"
    GMX_BIN="gmx_mpi"
fi
export MPI_BIN
export GMX_BIN

# slurm defaults supersedes hardware input parameters
if [[ -n "${SLURM_NTASKS+x}" ]] && [[ "${CPU_THREADS}" == "-1" ]]; then
    export CPU_THREADS="${SLURM_NTASKS}"
fi

if [[ -n ${SLURM_GPUS+x} ]]; then
    if [[ "${SLURM_GPUS}" == "1" ]] && [[ "${GPU_IDS}" == "-1" ]]; then
        export GPU_IDS="${SLURM_GPUS}"
    fi
fi

# define number of computational nodes
# shellcheck disable=SC2236
if [[ ! -n "${SLURM_JOB_NUM_NODES+x}" ]]; then
    export SLURM_JOB_NUM_NODES='1'
fi

# Hamiltonian replica exchange defaults
n_threads_per_node="$(grep -c ^processor /proc/cpuinfo)"
export N_SIM_PER_NODE=$(((N_REPLICA + SLURM_JOB_NUM_NODES - 1) / SLURM_JOB_NUM_NODES)) # number of replicas run per node (ceil division)
export N_THREAD_PER_SIM=$((n_threads_per_node / N_SIM_PER_NODE))                       # number of CPU threads per replica (floor division)
