#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on December 31st, 2021
# NOTE: Script assumes that it is called from the base directory of the project

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
# set -o nounset # exit when script tries to use undeclared variables

# Default Preferences ###################################################################

# configure variables
build_type="Release"
generator='Unix Makefiles'
c_compiler="/usr/bin/mpicc.openmpi"    # OPTIONS: [gcc, icc, mpicc]
cxx_compiler="/usr/bin/mpic++.openmpi" # OPTIONS: [g++, icpc, mpic++]
gpu="CUDA"                             # OPTIONS: [None, CUDA]
gpu_sm="86"                            # For 3080Ti (compute nodes) and 3070Ti (login node) devices
mpi="on"                               # OPTIONS: [on, off]
testing="1"                            # OPTIONS: [1: true, 0: false]

project_base_dir="$(pwd)"
compilers="gcc_10.4.0-cuda_11.8"

# PLUMED path variables
plumed_version="2.8.1"
plumed_exe="/nfs/zeal_nas/home_mount/modules/plumed_mpi_${plumed_version}-${compilers}/bin/plumed"

# GROMACS path variables
gromacs_version="2022.3"
gromacs_base_dir="${project_base_dir}/software/gromacs-${gromacs_version}"
build_dir="${gromacs_base_dir}/build/${build_type}"
cmake_install="/nfs/zeal_nas/home_mount/modules/gromacs_mpi_${gromacs_version}-plumed_mpi_${plumed_version}-${compilers}"

module_root="/home/modules"
compilers="gcc_10.4.0-cuda_11.8"
plumed_version="2.8.1"
gromacs_version="2022.3"

# PLUMED
export PLUMEDROOT="${module_root}/plumed_mpi_${plumed_version}-${compilers}"
export PLUMED_KERNEL="${PLUMEDROOT}/lib/libplumedKernel.so"
export PATH="${PLUMEDROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${PLUMEDROOT}/lib"
export LDFLAGS="${LDFLAGS} -L${PLUMEDROOT}/lib"
export CPPFLAGS="${CPPFLAGS} -I${PLUMEDROOT}/include"

# Patch GROMACS #########################################################################
# Documentation:
# PLUMED can be incorporated into gromacs using the standard patching procedure.
# Patching must be done in the gromacs root directory  _before_ the cmake command is invoked.
#
# On clusters you may want to patch gromacs using the static version of plumed, in this case
# building gromacs can result in multiple errors. One possible solution is to configure gromacs
# with these additional options:
#
# cmake -DBUILD_SHARED_LIBS=OFF -DGMX_PREFER_STATIC_LIBS=ON
#
# To enable PLUMED in a gromacs simulation one should use
# mdrun with an extra -plumed flag. The flag can be used to
# specify the name of the PLUMED input file, e.g.:
#
# gmx mdrun -plumed plumed.dat

cd "${gromacs_base_dir}" || exit

if [[ "${gromacs_version}" == "2022.3" ]]; then
    "${plumed_exe}" patch -p <<<4
fi

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
sudo make install

# add executables to PATH
# shellcheck disable=SC1091
source "${cmake_install}/bin/GMXRC"

cd "${project_base_dir}" || exit
