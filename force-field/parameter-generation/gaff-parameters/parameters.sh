#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# File created on April 20th, 2023 by Alec Glisman (GitHub: @alec-glisman)
#
# This script will run the antechamber program to generate GAFF parameters for
# a given molecule and use parmchk2 to verify the parameters.
#
# Short Tutorial: https://docs.bioexcel.eu/2020_06_09_online_ambertools4cp2k/04-parameters/index.html
# Long Tutorial: https://ambermd.org/tutorials/basic/tutorial4b/index.php
# AMBER Documentation: http://ambermd.org/antechamber/ac.html#antechamber
# ACPYPE Documentation: https://alanwilter.github.io/acpype/
# ParmEd Documentation: https://parmed.github.io/ParmEd/html/index.html

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# define variables
job='carbonate'
charge='-2'       # net charge of the molecule
forcefield='gaff' # force field to use {gaff, gaff2}
rb_dihedrals='1'  # use Ryckaert-Bellemans dihedrals instead of proper dihedrals {0, 1}

input_dir="$(pwd)/input"

# make the output directory and move into it
output_base_dir="output"
mkdir -p "${output_base_dir}"
cd "${output_base_dir}" || exit

# make the job directory and move into it
output_subdir="${job}_${forcefield}_rdb_${rb_dihedrals}"
mkdir -p "${output_subdir}"
cd "${output_subdir}" || exit

# copy input files
cp "${input_dir}/${job}.pdb" .
cp "${input_dir}/${job}-resp-charges.csv" "charges.csv"
cp "${input_dir}/tleap.in" .

# use sed to replace info on tleap.in file
sed -i "s/JOB/${job}/g" "tleap.in"
sed -i "s/FORCEFIELD/${forcefield}/g" "tleap.in"

# convert csv to crg file
cp "charges.csv" "${job}.crg"
# delete first 5 comma separated values
sed -i 's/[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,//' "${job}.crg"
# delete first line
sed -i '1d' "${job}.crg"

{
    echo "- Running antechamber to generate mol2 file with charges, atom types, and bond information"
    # NOTE: all-caps files are intermediate files and can be deleted
    antechamber \
        -i "${job}.pdb" -fi 'pdb' -rn "APY" \
        -o "${job}.mol2" -fo 'mol2' \
        -c 'rc' -cf "${job}.crg" -nc "${charge}" \
        -at "${forcefield}"
    echo ""
} 2>&1 | tee -a "antechamber.log"

# sleep for 5 seconds to allow the file to be written
sleep '5'

{
    echo "- Running parmchk2 to generate frcmod file with missing bond, angle, dihedral, and improper parameters"
    # REVIEW: check that the frcmod file does not contain  "ATTN: NEEDS REVISION"
    parmchk2 \
        -i "${job}.mol2" -f 'mol2' \
        -o "${job}.frcmod" -pf '1' \
        -w 'Y' -s "${forcefield}"
    echo ""
} 2>&1 | tee -a "parmchk2.log"

{
    echo "-Running tleap to generate prmtop and inpcrd files"
    tleap -f "tleap.in"
} 2>&1 | tee -a "tleap.log"

{
    echo "- Running acpype to generate gromacs topology/parameter files"
    # Ryckaert-Bellemans dihedrals
    if [[ "${rb_dihedrals}" == "0" ]]; then
        acpype \
            --atom_type="${forcefield}" \
            --prmtop="${job}.prmtop" --inpcrd="${job}.inpcrd"

    # proper dihedrals
    elif [[ "${rb_dihedrals}" == "1" ]]; then
        acpype \
            --atom_type="${forcefield}" \
            --gmx4 \
            --prmtop="${job}.prmtop" --inpcrd="${job}.inpcrd"

    # error
    else
        echo "ERROR: rb_dihedrals must be 0 or 1"
        exit 1
    fi
} 2>&1 | tee -a "acpype.log"

{
    echo "-Running ParmEd to generate gromacs topology/parameter files"
    python3 ../../ffconvert.py "${job}"
} 2>&1 | tee -a "parmed.log"

{
    echo "- Organizing files"
    # log files
    mkdir -p "logs"
    mv ./*.log "logs"
    # input files
    mkdir -p "input"
    cp "${job}.pdb" "tleap.in" -t "input"
    mv 'charges.csv' "input"
    # amber files
    mkdir -p "amber"
    mv 'ANTECHAMBER'* 'ATOMTYPE'* "${job}"* 'tleap.in' "amber"
}

# return to the original directory
echo "- Returning to original directory"
cd ../..
