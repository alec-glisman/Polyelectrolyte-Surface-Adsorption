#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Created by Alec Glisman (GitHub @alec-glisman) on May 5th, 2023
#
# This script runs the energy minimization of the carbonate molecule
# using the GAFF force field. The output is a .pdb file of the minimized
# structure. The script also generates a .log file of the energy
# minimization process.

# variable setting
pdb="$(pwd)/input/carbonate_ion.pdb"
mdp="$(pwd)/input/em.mdp"
ffname="gaff"
ffdir="$(pwd)/../../eccrpa-force-fields/${ffname}.ff"
outdir="$(pwd)/output"
logdir="$(pwd)/log"

# make directories
mkdir -p "${outdir}"
mkdir -p "${logdir}"

# symlink force field
ln -s "${ffdir}" "${ffname}.ff"

# set file names
fname="carbonate_ion"

# convert pdb to gmx
{
    gmx pdb2gmx \
        -f "${pdb}" \
        -o "${fname}.gro" \
        -ff "${ffname}" \
        -water 'none'
} 2>&1 | tee "${logdir}/pdb2gmx.log"

# place in 9 nm cubic box
{
    gmx editconf \
        -f "${fname}.gro" \
        -o "${fname}.gro" \
        -bt "cubic" \
        -box "9.0" \
        -c
} 2>&1 | tee "${logdir}/editconf.log"
# create tpr file
{
    gmx grompp \
        -f "${mdp}" \
        -c "${fname}.gro" \
        -o "${fname}.tpr" \
        -maxwarn '1' # net charge
} 2>&1 | tee "${logdir}/grompp.log"

# run energy minimization
{
    gmx mdrun \
        -v \
        -deffnm "${fname}"
} 2>&1 | tee "${logdir}/mdrun.log"

# convert last frame of trr to pdb
{
    gmx trjconv \
        -f "${fname}.trr" \
        -s "${fname}.tpr" \
        -o "${fname}.pdb" \
        -dump '10000000000' \
        -conect -center -pbc 'mol'
} 2>&1 | tee "${logdir}/trjconv.log"

# remove force field symlink
rm "${ffname}.ff"
# remove backup files
rm \#*

# move files to output directory
mv "${fname}."* "${outdir}"
mv 'posre.itp' 'mdout.mdp' 'topol.top' "${outdir}"
