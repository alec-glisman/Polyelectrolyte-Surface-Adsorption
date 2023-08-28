#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on December 31st, 2021
# NOTE: Script assumes that it is called from the base directory of the project
# REVIEW: Cannot install on MacOSX, fails on building step

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# Default Preferences ###################################################################

# configure variables
c_compiler="/usr/bin/mpicc.openmpi"    # OPTIONS: [gcc, icc, mpicc]
cxx_compiler="/usr/bin/mpic++.openmpi" # OPTIONS: [g++, icpc, mpic++]
python_exe="/usr/bin/python3.10"

project_base_dir="$(pwd)"
compilers="gcc_10.4.0-cuda_11.8"

# PLUMED path variables
plumed_version="2.8.1"
plumed_base_dir="${project_base_dir}/software/plumed-${plumed_version}"
install_dir="/nfs/zeal_nas/home_mount/modules/plumed_mpi_${plumed_version}-${compilers}"

# Install PLUMED #######################################################################
cd "${plumed_base_dir}" || exit

# clean existing builds
make clean

# configure
./configure \
    --prefix="${install_dir}" \
    CXX="${cxx_compiler}" \
    CC="${c_compiler}" \
    PYTHON_BIN="${python_exe}"

# build
make -j32

# test
make -j32 check || true

# install
sudo make install

cd "${project_base_dir}" || exit
