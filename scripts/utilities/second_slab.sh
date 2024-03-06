#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2024-03-04
# Description: Script to create initial system for MD simulations
# Usage      : ./second_slab.sh
# Notes      : Script assumes that global variables have been set in a
#             submission/input/*.sh script. Script should only be called from
#             the equilibration.sh script.

z_buffer="0.0" # [nm]
sim_name="npt_eqbm"
archive_dir="3-second-slab"
log_file="second_slab.log"

# find path to this script
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
project_path="${script_path}/../.."

# ##############################################################################
# Add second slab to box #######################################################
# ##############################################################################
# check if output gro file already exists
if [[ -f "${archive_dir}/${sim_name}_2slab.gro" ]]; then
    echo "DEBUG: Second slab already added"
else
    {
        echo "DEBUG: Adding second slab to box"

        # copy crystal.pdb from initialization
        cp -np "../1-energy-minimization/crystal.gro" "crystal.gro" || exit 1

        # find maximum z-coordinate of box from previous gro file
        box_dim="$(tail -n 1 "${sim_name}.gro")"
        z_height="$(echo "${box_dim}" | awk '{print $3}')"

        # calculate z-height of crystal and move slab to desired position
        z_coords="$(awk 'NR>2 {print $6}' "crystal.gro")"
        z_coords="$(echo "${z_coords}" | head -n -1 | sort -n)"
        z_max="$(echo "${z_coords}" | tail -n 1)"
        z_min="$(echo "${z_coords}" | head -n 1)"
        z_height_crystal="$(echo "scale=5; ${z_max} - ${z_min}" | bc)"
        z_translate="$(echo "scale=5; ${z_height} + ${z_max}" | bc)"
        z_height_2slab="$(echo "scale=5; ${z_height} + ${z_height_crystal} + ${z_buffer}" | bc)"

        # insert "-" at column 39 in all lines of gro file to reflect crystal on z-axis
        awk '{print substr($0,1,38)"-"substr($0,40)}' "crystal.gro" >"crystal_reflected.gro"
        head -n 2 crystal.gro >temp.txt
        tail -n +3 crystal_reflected.gro >>temp.txt
        head -n -1 temp.txt >temp2.txt
        mv temp2.txt temp.txt
        tail -n 1 crystal.gro >>temp.txt
        mv temp.txt crystal_reflected.gro

        # move reflected crystal to top of box
        "${GMX_BIN}" editconf \
            -f "crystal_reflected.gro" \
            -o "crystal_reflected.gro" \
            -translate 0 0 "${z_translate}"

        # get crystal coordinates for a dat file
        z_cryst="$(awk 'NR>2 {print $6}' "crystal_reflected.gro")"
        z_cryst="$(echo "${z_cryst}" | head -n -1)"
        y_cryst="$(awk 'NR>2 {print $5}' "crystal_reflected.gro")"
        y_cryst="$(echo "${y_cryst}" | head -n -1)"
        x_cryst="$(awk 'NR>2 {print $4}' "crystal_reflected.gro")"
        x_cryst="$(echo "${x_cryst}" | head -n -1)"
        paste <(echo "${x_cryst}") <(echo "${y_cryst}") <(echo "${z_cryst}") >positions.dat

        # increase box size in z-dimension by z_height_crystal
        cp -np "${sim_name}.gro" "${sim_name}_2slab_pre.gro" || exit 1
        sed -i "s/${z_height}/${z_height_2slab}/" "${sim_name}_2slab_pre.gro"

        # convert box and crystal to pdb files
        "${GMX_BIN}" editconf \
            -f "${sim_name}_2slab_pre.gro" \
            -o "${sim_name}_2slab_pre.pdb"
        "${GMX_BIN}" editconf \
            -f "crystal_reflected.gro" \
            -o "crystal_reflected.pdb"

        # remove unnecessary lines from pdb files
        sed -i '/^TER/d' "crystal_reflected.pdb"
        sed -i '/^ENDMDL/d' "crystal_reflected.pdb"
        sed -i "/^TITLE.*/d" "${sim_name}_2slab_pre.pdb
        sed -i "/^REMARK.*/d" "${sim_name}_2slab_pre.pdb
        sed -i "/^CRYST1.*/d" "${sim_name}_2slab_pre.pdb
        sed -i "/^MODEL.*/d" "${sim_name}_2slab_pre.pdb

        # merge pdb files into gro file
        \cat "crystal_reflected.pdb" "${sim_name}_2slab_pre.pdb" >"${sim_name}_2slab.pdb"
        "${GMX_BIN}" editconf \
            -f "${sim_name}_2slab.pdb" \
            -o "${sim_name}_2slab.gro"

        # move files to archive directory
        mkdir -p "${archive_dir}"
        mv "crystal.gro" "${archive_dir}/"
        mv "crystal_reflected.gro" "${archive_dir}/"
        mv "crystal_reflected.pdb" "${archive_dir}/"
        mv "positions.dat" "${archive_dir}/"
        mv "${sim_name}_2slab_pre.gro" "${archive_dir}/"
        mv "${sim_name}_2slab_pre.pdb" "${archive_dir}/"
        mv "${sim_name}_2slab.pdb" "${archive_dir}/"
        mv "${sim_name}_2slab.gro" "${archive_dir}/"
        cp "${archive_dir}/${sim_name}_2slab.gro" "${archive_dir}/${sim_name}.gro"
    } >>"${log_file}" 2>&1
fi

# ##############################################################################
# Remake system topology #######################################################
# ##############################################################################

# update number of atoms in topology file
if [[ -f "${archive_dir}/topol.top" ]]; then
    echo "DEBUG: Topology file already updated"

else
    echo "DEBUG: Updating topology file"
    {
        # get all lines [ molecules ] and following from topol.top
        grep -A 1000 "molecules" topol.top >temp.txt
        n_mol_slab="$(grep "Ion_chain_X" temp.txt | awk '{print $2}')"
        n_mol_2slab="$(echo "2 * ${n_mol_slab}" | bc)"
        sed -i "s/${n_mol_slab}/${n_mol_2slab}/" temp.txt
        # replace [ molecules ] and following in topol.top
        sed -i '/molecules/,$d' topol.top
        cat temp.txt >>topol.top
        rm temp.txt
        cp topol.top "${archive_dir}/"
    } >>"${log_file}" 2>&1
    echo "DEBUG: n_mol_slab = ${n_mol_slab}"
    echo "DEBUG: n_mol_2slab = ${n_mol_2slab}"

fi

# ##############################################################################
# Remake system index ##########################################################
# ##############################################################################

# Current groups:

if [[ -f "${archive_dir}/index.ndx" ]]; then
    echo "DEBUG: Index file already updated"
else
    # call python script to update index file
    echo "DEBUG: Updating index file"
    cp -np "index.ndx" "${archive_dir}/index_1slab.ndx" || exit 1
    "${GMX_BIN}" make_ndx \
        -f "${sim_name}.gro" \
        -n "index.ndx" \
        -o "index.ndx" <<EOF
q
EOF

    python3 "${project_path}/python/twoslab_index.py" \
        -i "index.ndx" \
        -g "${sim_name}.gro" \
        -o "index.ndx" \
        -v || exit 1

    cp "index.ndx" "${archive_dir}/"
    cp -np "index.ndx" "${archive_dir}/index_1slab.ndx" || exit 1
    "${GMX_BIN}" make_ndx \
        -f "${sim_name}.gro" \
        -n "index.ndx" \
        -o "index.ndx" <<EOF
q
EOF
fi
