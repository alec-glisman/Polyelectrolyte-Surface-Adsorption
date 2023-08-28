#!/usr/bin/env bash
# Created by Alec Glisman (GitHub: @alec-glisman) on December 31st, 2021
# NOTE: Script assumes it is called from "poly-acrylic-acid" directory

# input variables
poly_len="32"
ion="1" # OPTIONS: (0: un-ionized, 1: completely ionized, 0.5: half-and-half)
tacticity="atactic"

# internal variables
tag="PAA-${tacticity}-${poly_len}mer-H-end-f=${ion}"
data_dir="../poly-acrylic-acid/charmm-gui"
output_dir="${tag}/0-pdb-clean"
tar_file="${data_dir}/${tacticity}/f=${ion}/charmm-gui-${tag}.tar"
tar_pdb_file="*/psfcrdreader/p1_raw.pdb"

# make parent directory
mkdir -p "${output_dir}"

# choose monomer units
if [[ $ion == "1" ]]; then
    charmm_mon="AACI"
    left_start_mon="LAI"
    right_end_mon="RAI"
    central_mon="ACI"
elif [[ $ion == "0" ]]; then
    charmm_mon="AAC"
    left_start_mon=" LAN"
    right_end_mon=" RAN"
    central_mon=" ACN"
elif [[ $ion == "0.5" ]]; then
    charmm_mon="[AAC,AACI]"
    left_start_mon="LAZ"
    right_end_mon="RAZ"
    central_mon="ACZ"
fi

# unarchive pdb file
if [[ $OSTYPE == 'darwin'* ]]; then
    gtar -xf "${tar_file}" --wildcards "$tar_pdb_file" --strip-components=2
else
    tar -xf "${tar_file}" --wildcards "$tar_pdb_file" --strip-components=2
fi
# rename pdb file with current system parameters
mv p1_raw.pdb "${tag}.pdb"
cp "${tag}.pdb" "${output_dir}"

# rename residues (columns 18--20) & add chain identifier (column 22)
if [[ $OSTYPE == 'darwin'* ]]; then
    gsed -i "s/${charmm_mon} /${central_mon} A/" "${tag}.pdb"
    gsed -i "s/${central_mon} A   1 /${left_start_mon} A   1 /" "${tag}.pdb"
    gsed -i "s/${central_mon} A  ${poly_len} /${right_end_mon} A  ${poly_len} /" "${tag}.pdb"
    gsed -i "s/${central_mon} A   ${poly_len}/${right_end_mon} A  ${poly_len}/" "${tag}.pdb"

else
    sed -i "s/${charmm_mon} /${central_mon} A/" "${tag}.pdb"
    sed -i "s/${central_mon} A   1 /${left_start_mon} A   1 /" "${tag}.pdb"
    sed -i "s/${central_mon} A  ${poly_len} /${right_end_mon} A  ${poly_len} /" "${tag}.pdb"
    sed -i "s/${central_mon} A   ${poly_len}/${right_end_mon} A  ${poly_len}/" "${tag}.pdb"
fi

# remove segment identifier (columns 73-74) &  add element symbol (columns 77-78, right justify)
gawk -i inplace ' {
    n=split($0,a," ",b)
    a[12]="     "substr(a[3],1,1)
    line=b[0]
    for (i=1;i<=n; i++)
        line=(line a[i] b[i])
    print line
    }' "${tag}.pdb"

# move output pdb file
mv "${tag}.pdb" "${output_dir}/${tag}_clean.pdb"
