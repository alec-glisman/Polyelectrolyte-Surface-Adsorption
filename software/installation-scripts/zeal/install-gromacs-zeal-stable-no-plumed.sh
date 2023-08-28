#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on December 31st, 2021
# NOTE: Script assumes that it is called from the base directory of the project

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# Default Preferences ###################################################################

# configure variables
build_type="Release"        # OPTIONS: [Debug, Release]
generator='Unix Makefiles'  # OPTIONS: [Unix Makefiles, Ninja]
c_compiler="/usr/bin/gcc"   # OPTIONS: [gcc, gcc-11, icc, mpicc]
cxx_compiler="/usr/bin/g++" # OPTIONS: [g++, g++-11, icpc, mpic++]
gpu="CUDA"                  # OPTIONS: [None, CUDA]
gpu_sm="86"                 # For 3080Ti (compute nodes) and 3070Ti (login node) devices
mpi="off"                   # OPTIONS: [on, off]
testing="1"                 # OPTIONS: [1: true, 0: false]

project_base_dir="$(pwd)"
compilers="gcc_10.4.0-cuda_11.8"

# GROMACS path variables
gromacs_version="2022.3"
gromacs_base_dir="${project_base_dir}/software/gromacs-${gromacs_version}"
build_dir="${gromacs_base_dir}/build/${build_type}"
cmake_install="/nfs/zeal_nas/home_mount/modules/gromacs_${gromacs_version}-${compilers}"

cd "${gromacs_base_dir}" || exit

# Install GROMACS #######################################################################
# make build directory
mkdir -p "${build_dir}"

# configure
cmake -G "${generator}" -B "${build_dir}" \
    -DCMAKE_BUILD_TYPE="${build_type}" \
    -DCMAKE_INSTALL_PREFIX="${cmake_install}" \
    -DCMAKE_C_COMPILER="${c_compiler}" \
    -DCMAKE_CXX_COMPILER="${cxx_compiler}" \
    -DGMX_MPI="${mpi}" \
    -DGMX_GPU="${gpu}" \
    -DGMX_CUDA_TARGET_SM="${gpu_sm}" \
    -DREGRESSIONTEST_DOWNLOAD="ON" \
    -DGMX_BUILD_OWN_FFTW="ON"

# build
cmake --build "${build_dir}" -j32
cd "${build_dir}" || exit

# test
if [[ "${testing}" = "1" ]]; then
    # NOTE: It is okay if Test MdrunOutputTests fails. @SOURCE: https://mailman-1.sys.kth.se/pipermail/gromacs.org_gmx-users/2020-April/129090.html
    export PATH="${build_dir}/bin:${PATH}"
    make -j32 check || true
fi

# install
sudo make -j32 install

cd "${project_base_dir}" || exit
