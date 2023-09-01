#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-08-30
# Description: Script to set generic global variables pertaining to the system.
# Notes      : Script should only be called from the main run.sh script.

# find path to this script
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
project_path="${script_path}/../.."

# ##############################################################################
# Set simulation identifiers ###################################################
# ##############################################################################

# Polyelectrolyte tag
if [[ "${MONOMER^^}" == "ASP" ]] || [[ "${MONOMER^^}" == "GLU" ]]; then
    if [[ -z "${BLOCK}" ]]; then
        echo "ERROR: Block copolymers not implemented for aspartic acid or glutamic acid."
        exit 1
    fi
    stereochemistry="Lenantiomer"
    n_terminus_group="amine"
    c_terminus_group="carboxylicacid"
    monomer_tags="${stereochemistry}-${n_terminus_group}-${c_terminus_group}"
    CHAIN_TAG="${N_CHAIN}chain-P${MONOMER}-${N_MONOMER}mer"

else
    tacticity="atactic"
    terminus_group="Hend"
    monomer_tags="${tacticity}-${terminus_group}"
    if [[ -z "${BLOCK}" ]]; then
        CHAIN_TAG="${N_CHAIN}chain-P${MONOMER}-${N_MONOMER}mer"
    else
        CHAIN_TAG="${N_CHAIN}chain-P${MONOMER}-${BLOCK}_block-${N_MONOMER}mer"
    fi
fi

# Crystal tag
CRYSTAL_TAG="${CRYSTAL}-${SURFACE}surface-${SURFACE_SIZE}nm_surface-${BOX_HEIGHT}nm_vertical"

# Ion tag
ION_TAG="${N_CARBONATE}Crb-${N_CALCIUM}Ca-${N_SODIUM}Na-${N_CHLORINE}Cl"

# Simulation tag
SIMULATION_TAG="${TEMPERATURE_K}K-${PRESSURE_BAR}bar-${PRODUCTION_ENSEMBLE}"

# Combine tags
TAG="${CRYSTAL_TAG}-${CHAIN_TAG}-${ION_TAG}-${SIMULATION_TAG}"
if [[ -n "${SLURM_JOB_ID+x}" ]]; then
    TAG="sjobid_${SLURM_JOB_ID}-${TAG}"
else
    TAG="sjobid_0-${TAG}"
fi
export TAG

# check if TAG_APPEND is set, if so append to TAG
if [[ -n "${TAG_APPEND+x}" ]]; then
    export TAG="${TAG}-${TAG_APPEND}"
fi

# ##############################################################################
# Set PDB files ################################################################
# ##############################################################################

# set pdb file for crystal surface
export PDB_CRYSTAL="${project_path}/initial-structure/calcium-carbonate-crystal/supercell/${CRYSTAL}-${SURFACE}surface-${SURFACE_SIZE}nm.pdb"

# subdirectory of pdb files
PDB_INPUT_DIR="${project_path}/initial-structure/polyelectrolyte/chain" # path to .pdb input directory
if [[ -z "${BLOCK}" ]]; then
    PDB_INPUT_DIR="${PDB_INPUT_DIR}/homopolymer"
    pdb_file_tags="P${MONOMER}-${N_MONOMER}mer-${monomer_tags}"
else
    PDB_INPUT_DIR="${PDB_INPUT_DIR}/copolymer"
    pdb_file_tags="P${MONOMER}-${BLOCK}_block-${N_MONOMER}mer-${monomer_tags}"
fi
# full path to pdb file
export PDB_CHAIN="${PDB_INPUT_DIR}/${pdb_file_tags}.pdb"

# ##############################################################################
# Set force field directory ####################################################
# ##############################################################################

if [[ "${MONOMER^^}" == "ASP" ]] || [[ "${MONOMER^^}" == "GLU" ]]; then
    FF_DIR="${project_path}/force-field/eccrpa-force-fields/amber99sb-star-ildn-q.ff"
elif [[ "${MONOMER^^}" == "ACR" ]] || [[ "${MONOMER^^}" == "ACN" ]] || [[ "${MONOMER^^}" == "ACE" ]] || [[ "${MONOMER^^}" == "ALC" ]]; then
    FF_DIR="${project_path}/force-field/eccrpa-force-fields/gaff.ff"
else
    echo "ERROR: Unrecognized monomer: ${MONOMER}"
    exit 1
fi
export FF_DIR
