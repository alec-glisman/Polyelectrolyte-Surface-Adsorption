#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on December 31st, 2021
# NOTE: Script assumes that it is called from the base directory of the project
# REVIEW: Cannot install on MacOSX, fails on building step

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# Default Preferences ###################################################################

# configure variables
c_compiler="/usr/bin/mpicc.openmpi"
cxx_compiler="/usr/bin/mpic++.openmpi"
python_exe="/usr/bin/python3.10"

project_base_dir="$(pwd)"
compilers="gcc_12.3.0-cuda_12.0.140"

# PLUMED path variables
plumed_version="2.9.0"
plumed_base_dir="${project_base_dir}/plumed-${plumed_version}"
install_dir="/home/aglisman/software/plumed_mpi_${plumed_version}-${compilers}"

# Install PLUMED #######################################################################
cd "${plumed_base_dir}" || exit

# clean existing builds
make clean

# configure
./configure \
    --enable-modules='+funnel+opes+pytorch+sasa+ves' \
    --prefix="${install_dir}" \
    CXX="${cxx_compiler}" \
    CC="${c_compiler}" \
    PYTHON_BIN="${python_exe}"

# build
make -j24

# test
make -j24 check || true

# install
make install

cd "${project_base_dir}" || exit
