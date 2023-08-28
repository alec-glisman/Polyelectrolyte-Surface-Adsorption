#!/usr/bin/env bash

files=(
    "orca_qm_paan_resp"
    "orca_qm_paan_esp"
    "orca_qm_paai_resp"
    "orca_qm_paai_esp"
    "orca_qm_pva_resp"
    "orca_qm_pva_esp"
    "orca_qm_pvac_resp"
    "orca_qm_pvac_esp"
)

for file in "${files[@]}"; do
    sbatch \
        --partition='all' --qos='dow' --account='dow' \
        --nodes='1' --ntasks-per-node='24' --mem='20G' \
        --mail-user='slurm.notifications@gmail.com' --mail-type='BEGIN,END,FAIL' \
        --output='logs/jobid_%j-node_%N-%x.log' --error='logs/jobid_%j-node_%N-%x.log' \
        "${file}.sh"
done
