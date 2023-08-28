#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on December 31st, 2021
# NOTE: Script assumes that it is called from the base directory of the project
# REVIEW: Cannot install on MacOSX, fails on building step

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# Default Preferences ###################################################################
echo "INFO: Setting default preferences"

# configure variables
c_compiler="/usr/bin/gcc-12"
cxx_compiler="/usr/bin/g++-12"
python_exe="/usr/bin/python3.10"
cuda_toolkit="/usr/local/cuda-12.0"

project_base_dir="$(pwd)"
compilers="gcc_12.3.0-cuda_12.0.140"

# UCX path variables
ucx_version="1.14.1"
ucx_name="ucx-${ucx_version}"
ucx_install_dir="/home/aglisman/software/${ucx_name}-${compilers}"

# OpenMPI path variables
mpi_version="4.1.5"
mpi_name="openmpi-${mpi_version}"
mpi_install_dir="/home/aglisman/software/openmpi_${mpi_version}-${compilers}"

# move to project base directory
cd "${project_base_dir}" || exit

# Install UCX ###########################################################################
echo "INFO: Installing UCX"

# unpack
cd "${project_base_dir}" || exit
tar -xvf "${ucx_name}.tar.xz"
cd "${ucx_name}" || exit

# configure
./contrib/configure-release \
    --prefix="${ucx_install_dir}" \
    CXX="${cxx_compiler}" \
    CC="${c_compiler}" \
    PYTHON_BIN="${python_exe}"

# make and install
make -j24
make install

# remove unpacked directory
cd "${project_base_dir}" || exit
rm -rf "${ucx_name}"

# Install OpenMPI #######################################################################
echo "INFO: Installing OpenMPI"

# unpack
cd "${project_base_dir}" || exit
tar -xvf "${mpi_name}.tar.xz"
cd "${mpi_name}" || exit

# configure
./configure \
    --with-cuda="${cuda_toolkit}" \
    --prefix="${mpi_install_dir}" \
    CXX="${cxx_compiler}" \
    CC="${c_compiler}" \
    PYTHON_BIN="${python_exe}"

# install
make -j24 all install

cd "${project_base_dir}" || exit
