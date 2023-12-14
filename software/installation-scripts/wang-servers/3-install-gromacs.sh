#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on December 31st, 2021
# NOTE: Script assumes that it is called from the base directory of the project

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# Default Preferences ###################################################################
echo "INFO: Setting default preferences"

# path and version variables for previous installations
mpi_version="4.1.5"
plumed_version="2.9.0"
module_root="/home/aglisman/software"
compilers="gcc_12.3.0-cuda_12.2"
cuda_toolkit="/usr/local/cuda-12.2"

# get latest MPI compilers installed in previous script
# NOTE: Use a "CUDA aware" MPI implementation
# To check if MPI is CUDA aware run:
#   ompi_info --parsable --all | grep mpi_built_with_cuda_support:value
c_compiler="${module_root}/openmpi_${mpi_version}-${compilers}/bin/mpicc"
cxx_compiler="${module_root}/openmpi_${mpi_version}-${compilers}/bin/mpic++"

# add compiler information to global environment
export PATH="${module_root}/openmpi_${mpi_version}-${compilers}/bin:${PATH}"
export LD_LIBRARY_PATH="${module_root}/openmpi_${mpi_version}-${compilers}/lib:${LD_LIBRARY_PATH}"

# project base directory
project_base_dir="$(pwd)"

# GROMACS path variables
gromacs_version="2023"
gromacs_name="gromacs-${gromacs_version}"
build_dir="${project_base_dir}/${gromacs_name}/build"
cmake_install="${HOME}/software/gromacs_mpi_${gromacs_version}-plumed_mpi_${plumed_version}-${compilers}"

# PLUMED path variables
plumed_exe="/home/aglisman/software/plumed_mpi_${plumed_version}-${compilers}/bin/plumed"
# PLUMED global environment variables
export PLUMEDROOT="${HOME}/software/plumed_mpi_${plumed_version}-${compilers}"
export PLUMED_KERNEL="${PLUMEDROOT}/lib/libplumedKernel.so"
export PATH="${PLUMEDROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${PLUMEDROOT}/lib"
export LDFLAGS="${LDFLAGS} -L${PLUMEDROOT}/lib"
export CPPFLAGS="${CPPFLAGS} -I${PLUMEDROOT}/include"

# Unarchive GROMACS #####################################################################
cd "${project_base_dir}" || exit
tar -xvf "${gromacs_name}.tar.xz"
cd "${gromacs_name}" || exit

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
echo "INFO: Patching GROMACS"

if [[ "${gromacs_version}" == "2023" ]]; then
    "${plumed_exe}" patch -p <<<4
else
    echo "ERROR: GROMACS version ${gromacs_version} is not supported by PLUMED version ${plumed_version}"
    exit 1
fi

# Install GROMACS #######################################################################
echo "INFO: Installing GROMACS"

# make build directory
mkdir -p "${build_dir}"

# configure
cmake -G 'Unix Makefiles' -B "${build_dir}" \
    -DCMAKE_BUILD_TYPE='Release' \
    -DCMAKE_INSTALL_PREFIX="${cmake_install}" \
    -DCMAKE_C_COMPILER="${c_compiler}" \
    -DCMAKE_CXX_COMPILER="${cxx_compiler}" \
    -DGMX_MPI='on' \
    -DGMX_GPU='CUDA' \
    -DCUDA_TOOLKIT_ROOT_DIR="${cuda_toolkit}" \
    -DREGRESSIONTEST_DOWNLOAD="ON" \
    -DGMX_BUILD_OWN_FFTW="ON"

# build
cmake --build "${build_dir}" -j24
cd "${build_dir}" || exit

# test
# NOTE: It is okay if Test MdrunOutputTests fails. @SOURCE: https://mailman-1.sys.kth.se/pipermail/gromacs.org_gmx-users/2020-April/129090.html
export PATH="${build_dir}/bin:${PATH}"
make -j24 check || true

# install
make -j24 install

# remove unpacked directory
cd "${project_base_dir}" || exit
rm -rf "${gromacs_name}"
