# Spack information

## Package manager installation

This script will install Spack and activate its functionality.

```[bash]
git clone --depth=100 --branch=releases/v0.20 https://github.com/spack/spack.git ~/spack
cd ~/spack
. share/spack/setup-env.sh
```

## Sample environment creation

This script will install the necessary binaries for the MD engine inside of an environment named `md`.

```[bash]
# make environment
spack env create md
spack env activate md

# add packages (gcc 11.3.0 in Ubuntu 22.04)
spack add gcc@11.3.0%gcc@11.3.0+nvptx
spack add plumed@2.8.1%gcc@11.3.0+gsl+mpi+shared
spack add gromacs@2022.3%gcc@11.3.0+blas+cuda+hwloc+lapack+mpi+openmp+plumed+shared ^plumed@2.8.1%gcc@11.3.0+mpi+shared
spack add packmol%gcc@11.3.0

# add packages (gcc 11.1.0 in Ubuntu 20.04 and 18.04)
spack add gcc@11.3.0%gcc@11.1.0+nvptx
spack add plumed@2.8.1%gcc@11.1.0+gsl+mpi+shared
spack add gromacs@2022.3%gcc@11.1.0+blas+cuda+hwloc+lapack+mpi+openmp+plumed+shared ^plumed@2.8.1%gcc@11.1.0+mpi+shared
spack add packmol%gcc@11.1.0

# install packages
spack concretize --force
spack install -j 24
```

## Sample bashrc file addition

This snippet should be added to the `~/.bashrc` (or `~/.zshrc`) file to automatically add Spack to all terminal sessions and activate the desired environment.

```[bash]
# Spack
source "${HOME}/spack/share/spack/setup-env.sh"
spack env activate md
```
