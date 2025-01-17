#!/usr/bin/env bash
# -*- coding: utf-8 -*-

n_jobs='12'
first_dependency='1'
dependency_code='afterany'
batch_script='2oneopes_6.sh'

# argument parsing
# 1st argument: input global indices to run {0..19}
if [ $# -eq 0 ]; then
    idx='0'
else
    idx="${1}"
fi
job_name="OP_6.${idx}"

# iterate over all jobs
echo "Submitting ${n_jobs} jobs with script ${batch_script} ${idx}"
jid_dep="${first_dependency}"
for job in $(seq 1 "${n_jobs}"); do
    jid="$(sbatch --dependency="${dependency_code}:${jid_dep}" --job-name "${job_name}-${job}" "${batch_script}" "${idx}" | awk '{print $4}')"
    echo "Submitted job ${job_name}-${job} (${job}/${n_jobs}) with job id ${jid} and dependency ${jid_dep}"
    jid_dep="${jid}"
done
