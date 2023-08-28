#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# File created on April 19th, 2023 by Alec Glisman (GitHub: @alec-glisman)
# Original template provided by Pierre Walker
#

# built-in shell options
set -o errexit # exit when a command fails. Add || true to commands allowed to fail
set -o nounset # exit when script tries to use undeclared variables

# define variables
job='pva-3mer-Hcap'
orca_base_path='/home/aglisman/software/orca/orca_5_0_4_linux_x86-64_shared_openmpi411'
n_cpu='24'               # number of CPUs to use
method='HF'              # optimization method
basis='6-31G*'           # optimization basis set
tolerance='VeryTightSCF' # SCF convergence tolerance {TightSCF, VeryTightSCF, ExtremeSCF}
charge='0'               # net charge of the molecule
spin='1'                 # spin multiplicity of the molecule
fit='1'                  # fit charges to RESP (1) or ESP (2)

# get input dir
input_base_dir="$(pwd)/input"
input_dir="${input_base_dir}/${job}"

# find list of stereoisomers and
mapfile -t file_list < <(find "${input_dir}" -name "*.pdb" | sort -V)
# extract file name from path without extension
mapfile -t stereo_list < <(for file in "${file_list[@]}"; do basename "${file}" .pdb; done)

# make the output directory and move into it
output_base_dir="output"
mkdir -p "${output_base_dir}"
cd "${output_base_dir}" || exit

# make the job directory and move into it
output_subdir="${job}_${method}_${basis//\*/}_${tolerance}"
if [[ "${fit}" == "1" ]]; then
    output_subdir="${output_subdir}_RESP"
elif [[ "${fit}" == "2" ]]; then
    output_subdir="${output_subdir}_ESP"
else
    echo "ERROR: fit must be 1 (RESP) or 2 (ESP)"
    exit 1
fi

mkdir -p "${output_subdir}"
cd "${output_subdir}" || exit
cwd="$(pwd)"

# iterate through each stereoisomer
for i in "${!stereo_list[@]}"; do
    schem="${stereo_list[i]}"
    file="${file_list[i]}"

    # start in cwd
    cd "${cwd}" || exit

    # make schem directory and move into it
    mkdir -p "${schem}"
    cd "${schem}" || exit

    # copy over the generalized input file and rename JOBTITLE to match the job name
    cp "${input_base_dir}/job.inp" "${job}.inp"
    sed -i "s/METHOD/${method}/g" "${job}.inp"
    sed -i "s/BASIS/${basis}/g" "${job}.inp"
    sed -i "s/TOLERANCE/${tolerance}/g" "${job}.inp"
    sed -i "s/NCPU/${n_cpu}/g" "${job}.inp"
    sed -i "s/CHARGE/${charge}/g" "${job}.inp"
    sed -i "s/SPIN/${spin}/g" "${job}.inp"
    sed -i "s/JOBTITLE/${job}/g" "${job}.inp"
    # copy the pdb file over and convert it to an xyz file
    cp "${file}" "${job}.pdb"
    obabel "${job}.pdb" -O "${job}.xyz" 2>&1 | tee -a "obabel.log"
    # copy the equivalence constraint file over
    cp "${input_dir}/eqvcons.txt" .
    cp "${input_dir}/chgcons.txt" .

    # run the job using ORCA
    "${orca_base_path}/orca" "${job}.inp" \
        "-np ${n_cpu} --use-hwthread-cpus --bind-to core" \
        2>&1 | tee -a "orca.log"

    # produce a molden file needed for Multiwfn
    "${orca_base_path}/orca_2mkl" "${job}" -molden \
        2>&1 | tee -a "orca_2mkl.log"

    # run Multiwfn to get the partial charges (full list of options below)
    {
        Multiwfn <<EOF
${job}.molden.input
7
18
5
1
eqvcons.txt
6
1
chgcons.txt
3
2
1
0.2
0
4
2
0.00000001
3
0.00050
4
0.00100
0
${fit}
y
0
0
q
EOF
    } 2>&1 | tee -a "multiwfn.log"
done

# Multiwfn options
# $1: .molden.input input file
# $2: (7) population analysis and calculation of atomic charges
# $3: (18) restrained ElectroStatic Potential (RESP) atomic charges
# $4: (5) Set equivalence constraint in fitting, current: H in CH2 and CH3
# $5: (1) Load equivalence constraint setting from external plain text file
# $6: (eqvcons.txt) name of external plain text file
# $7: (6) Set charge constraint in fitting, current: none
# $8: (1) Load charge constraint setting from external plain text file
# $9: (chgcons.txt) name of external plain text file
# $10: (3) Set method and parameters for distributing fitting points, current: MK
# $11: (2): CHELPG grid
# $12: (1) Set grid spacing, current:   0.567 Bohr (  0.300 Angstrom)
# $13: (0.2) Grid spacing in Bohr
# $14: (0) Finished
# $15: (4) Set hyperbolic penalty and various other running parameters
# $16: (2) Set convergence threshold for RESP fitting, current: 1.0E-6
# $17: (0.00000001) Convergence threshold for RESP fitting
# $18: (3) Set restraint strength in stage 1 of standard RESP, current: 0.00050
# $19: (0.00050) Restraint strength in stage 1 of standard RESP
# $20: (4) Set restraint strength in stage 2 of standard RESP, current: 0.00100
# $21: (0.00100) Restraint strength in stage 2 of standard RESP
# $22: (0) Return
# $23: (1/2) start standard two-stage RESP / ESP fitting calculation
# $24: (y) yes, output atom coordinates with charges to .molden.chg in current folder
# $25: (0) go to population analysis menu from RESP menu
# $26: (0) go to main menu from population analysis menu
# $27: (q) exit program gracefully
