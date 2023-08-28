#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on December 31st, 2021
# NOTE: Script assumes that it is called from the software directory of the project
# REVIEW: Cannot install on MacOSX, fails on building step

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# Default Preferences ###################################################################
echo "INFO: Setting default preferences"

# path and version variables for previous installations
module_root="/home/modules"
compilers="gcc_12.3.0-cuda_12.2.128"
c_compiler="/usr/bin/mpicc.openmpi"
cxx_compiler="/usr/bin/mpic++.openmpi"

# add python information
python_exe="/usr/bin/python3.10"

# project base directory
project_base_dir="$(pwd)"

# PLUMED path variables
plumed_version="2.9.0"
plumed_name="plumed-${plumed_version}"
plumed_install_dir="${module_root}/plumed_mpi_${plumed_version}-${compilers}"

# Install PLUMED #######################################################################
echo "INFO: Installing PLUMED"

# unpack
cd "${project_base_dir}" || exit
tar -xvf "${plumed_name}.tar.xz"
cd "${plumed_name}" || exit

# configure
./configure \
    --enable-modules='+funnel+opes+pytorch+sasa+ves' \
    --prefix="${plumed_install_dir}" \
    CC="${c_compiler}" \
    CXX="${cxx_compiler}" \
    PYTHON_BIN="${python_exe}"

# build
make -j32

# test
make -j32 check || true

# install
sudo make install

# remove unpacked directory
cd "${project_base_dir}" || exit
rm -rf "${plumed_name}"
