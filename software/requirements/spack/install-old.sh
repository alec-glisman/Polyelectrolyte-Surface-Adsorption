#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Description: Install Spack and its dependencies for molecular dynamics
# simulations.
#
# Usage: ./install.sh
#
# Author: Alec Glisman (GitHub: @alec-glisman)
# Date: 2020-06-20
#

# variables
env_name="md"
gcc_version="11.3.0"

# Install Spack
git clone --depth=100 --branch=releases/v0.20 https://github.com/spack/spack.git ~/spack
cd ~/spack || exit
. share/spack/setup-env.sh

# make environment
spack env create "${env_name}"
spack env activate "${env_name}"

# add packages (gcc 11.3.0 in Ubuntu 22.04)
spack add "gcc@11.3.0%gcc@${gcc_version}+nvptx"
spack add plumed@2.8.1%gcc@${gcc_version}+gsl+mpi+shared
spack add gromacs@2022.3%gcc@${gcc_version}+blas+cuda+hwloc+lapack+mpi+openmp+plumed+shared ^plumed@2.8.1%gcc@${gcc_version}+mpi+shared
spack add packmol%gcc@${gcc_version}

# install packages
spack concretize --force
spack install

# add spack information to bashrc
echo ". ~/spack/share/spack/setup-env.sh" >>~/.bashrc
echo "spack env activate ${env_name}" >>~/.bashrc
