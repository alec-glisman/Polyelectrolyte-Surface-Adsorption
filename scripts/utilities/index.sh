#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2024-03-01
# Description: Script to create initial system for MD simulations
# Usage      : ./index.sh
# Notes      : Script assumes that global variables have been set in a
#             submission/input/*.sh script. Script should only be called from
#             the initialization.sh script.

log_file="index.log"
sim_name="energy_minimization"

# ##############################################################################
# Make Default Index File ######################################################
# ##############################################################################
echo "INFO: Making default index file" | tee -a "${log_file}"

{
    # create blank index file
    if [[ "${N_CHAIN}" -gt 0 ]]; then
        idx_group='17'
    else
        idx_group='6'
    fi

    "${GMX_BIN}" make_ndx \
        -f "${sim_name}.gro" \
        -o "index.ndx" \
        <<EOF
q
EOF

    # clear index_crystal.ndx file
    # shellcheck disable=SC2188
    >"index_crystal.ndx" || true
} >>"${log_file}" 2>&1

# ##############################################################################
# Polymer Groups to Index File #################################################
# ##############################################################################
if [[ "${N_CHAIN}" -gt 0 ]]; then
    echo "INFO: Adding polymer groups to index file" | tee -a "${log_file}"
    {
        "${GMX_BIN}" make_ndx \
            -f "pdb2gmx_clean.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a * & chain A
name ${idx_group} Chain
a O* & chain A
name $((idx_group + 1)) Chain_Oxygen

q
EOF
        idx_group=$((idx_group + 2))
    } >>"${log_file}" 2>&1
fi

# ##############################################################################
# Add Ion Groups to Index File #################################################
# ##############################################################################
echo "INFO: Adding ion groups to index file" | tee -a "${log_file}"
{
    # add aqueous sodium ions to index file
    if [[ "${N_SODIUM}" -gt 0 ]]; then
        "${GMX_BIN}" make_ndx \
            -f "${sim_name}.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a NA & ! chain A & ! chain B & ! r CRB
name ${idx_group} Aqueous_Sodium

q
EOF
        idx_group=$((idx_group + 1))
    fi

    # add aqueous calcium ions to index file
    if [[ "${N_CALCIUM}" -gt 0 ]]; then
        "${GMX_BIN}" make_ndx \
            -f "${sim_name}.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a CA & ! chain A & ! chain B
name ${idx_group} Aqueous_Calcium

q
EOF
        idx_group=$((idx_group + 1))
    fi

    # add aqueous chloride ions to index file
    if [[ "${N_CHLORINE}" -gt 0 ]]; then
        "${GMX_BIN}" make_ndx \
            -f "${sim_name}.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a CL & ! chain A & ! chain B
name ${idx_group} Aqueous_Chloride

q
EOF
        idx_group=$((idx_group + 1))
    fi

    # add aqueous carbonate ions to index file
    if [[ "${N_CARBONATE}" -gt 0 ]]; then
        "${GMX_BIN}" make_ndx \
            -f "${sim_name}.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
a CX* | a OX* & ! chain A & ! chain B
name ${idx_group} Aqueous_Carbonate
a CX* & ! chain A & ! chain B
name $((idx_group + 1)) Aqueous_Carbonate_Carbon
a OX* & ! chain A & ! chain B
name $((idx_group + 2)) Aqueous_Carbonate_Oxygen

q
EOF
        idx_group=$((idx_group + 3))
    fi

} >>"${log_file}" 2>&1

# ##############################################################################
# 3D PBC #######################################################################
# ##############################################################################
if [[ "${VACUUM}" == "False" ]]; then
    echo "INFO: Adding 3D PBC groups to index file" | tee -a "${log_file}"
    {
        "${GMX_BIN}" select \
            -f "crystal.pdb" \
            -s "crystal.pdb" \
            -n "index.ndx" \
            -on "index_crystal.ndx" \
            <<EOF
"Crystal" resname CRB CA
"Crystal_Bulk" same residue as (name CX1 CA and (z >= ${PDB_BULK_ZMIN} and z <= ${PDB_BULK_ZMAX}))
"Crystal_Top_Surface" same residue as (name CX1 CA and (z > ${PDB_BULK_ZMAX}))
"Crystal_Bottom_Surface" same residue as (name CX1 CA and (z < ${PDB_BULK_ZMIN}))
EOF
        # save group numbers
        group_crystal="${idx_group}"
        group_bulk="$((idx_group + 1))"
        group_top_surface="$((idx_group + 2))"
        group_bottom_surface="$((idx_group + 3))"

        # remove "f0_t0.000" from index file groups
        sed -i 's/_f0_t0.000//g' "index_crystal.ndx"
        # append crystal groups to index file
        cat "index_crystal.ndx" >>"index.ndx"
        idx_group=$((idx_group + 4))

        # add crystal sub-groups to index file
        "${GMX_BIN}" make_ndx \
            -f "crystal.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
${group_bulk} & ! a CA*
name ${idx_group} Crystal_Bulk_Carbonate
${group_bulk} & a CX*
name $((idx_group + 1)) Crystal_Bulk_Carbonate_Carbon
${group_bulk} & a OX*
name $((idx_group + 2)) Crystal_Bulk_Carbonate_Oxygen
${group_bulk} & ! a O* & ! a CX*
name $((idx_group + 3)) Crystal_Bulk_Calcium
${group_top_surface} & ! a CA*
name $((idx_group + 4)) Crystal_Top_Surface_Carbonate
${group_top_surface} & a CX*
name $((idx_group + 5)) Crystal_Top_Surface_Carbonate_Carbon
${group_top_surface} & a OX*
name $((idx_group + 6)) Crystal_Top_Surface_Carbonate_Oxygen
${group_top_surface} & ! a O* & ! a CX*
name $((idx_group + 7)) Crystal_Top_Surface_Calcium
${group_bottom_surface} & ! a CA*
name $((idx_group + 8)) Crystal_Bottom_Surface_Carbonate
${group_bottom_surface} & a CX*
name $((idx_group + 9)) Crystal_Bottom_Surface_Carbonate_Carbon
${group_bottom_surface} & a OX*
name $((idx_group + 10)) Crystal_Bottom_Surface_Carbonate_Oxygen
${group_bottom_surface} & ! a O* & ! a CX*
name $((idx_group + 11)) Crystal_Bottom_Surface_Calcium

q
EOF
        idx_group=$((idx_group + 12))

        # add system section groups to index file
        "${GMX_BIN}" make_ndx \
            -f "${sim_name}.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
${group_bulk}
name $((idx_group)) Frozen
! ${group_bulk}
name $((idx_group + 1)) Mobile 
! ${group_crystal}
name $((idx_group + 2)) Aqueous

q
EOF
        idx_group=$((idx_group + 3))
    } >>"${log_file}" 2>&1
fi

# ##############################################################################
# 2D PBC #######################################################################
# ##############################################################################
if [[ "${VACUUM}" == "True" ]]; then
    echo "INFO: Adding 2D PBC groups to index file" | tee -a "${log_file}"
    {
        "${GMX_BIN}" select \
            -f "crystal.pdb" \
            -s "crystal.pdb" \
            -n "index.ndx" \
            -on "index_crystal.ndx" \
            <<EOF
"Crystal" resname CRB CA
"Crystal_Bulk" same residue as (name CX1 CA and (z <= ${PDB_BULK_ZMAX}))
"Crystal_Top_Surface" same residue as (name CX1 CA and (z > ${PDB_BULK_ZMAX}))
EOF
        # save group numbers
        group_crystal="${idx_group}"
        group_bulk="$((idx_group + 1))"
        group_top_surface="$((idx_group + 2))"

        # remove "f0_t0.000" from index file groups
        sed -i 's/_f0_t0.000//g' "index_crystal.ndx"
        # append crystal groups to index file
        cat "index_crystal.ndx" >>"index.ndx"
        idx_group=$((idx_group + 3))

        # add crystal sub-groups to index file
        "${GMX_BIN}" make_ndx \
            -f "crystal.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
${group_bulk} & ! a CA*
name ${idx_group} Crystal_Bulk_Carbonate
${group_bulk} & a CX*
name $((idx_group + 1)) Crystal_Bulk_Carbonate_Carbon
${group_bulk} & a OX*
name $((idx_group + 2)) Crystal_Bulk_Carbonate_Oxygen
${group_bulk} & ! a O* & ! a CX*
name $((idx_group + 3)) Crystal_Bulk_Calcium
${group_top_surface} & ! a CA*
name $((idx_group + 4)) Crystal_Top_Surface_Carbonate
${group_top_surface} & a CX*
name $((idx_group + 5)) Crystal_Top_Surface_Carbonate_Carbon
${group_top_surface} & a OX*
name $((idx_group + 6)) Crystal_Top_Surface_Carbonate_Oxygen
${group_top_surface} & ! a O* & ! a CX*
name $((idx_group + 7)) Crystal_Top_Surface_Calcium

q
EOF
        idx_group=$((idx_group + 8))

        # add system section groups to index file
        "${GMX_BIN}" make_ndx \
            -f "${sim_name}.pdb" \
            -n "index.ndx" \
            -o "index.ndx" \
            <<EOF
${group_bulk}
name $((idx_group)) Frozen
! ${group_bulk}
name $((idx_group + 1)) Mobile 
! ${group_crystal}
name $((idx_group + 2)) Aqueous

q
EOF
        idx_group=$((idx_group + 3))
    } >>"${log_file}" 2>&1
fi
