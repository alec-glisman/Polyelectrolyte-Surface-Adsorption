#!/usr/bin/env bash
# -*- coding: utf-8 -*-

n_jobs='7'
first_dependency='1'
dependency_code='afterany'
batch_script='2oneopes_5.5.0.sh'
# idx='6'
# job_name='4.7-md'

# iterate over all jobs
echo "Submitting ${n_jobs} jobs with script ${batch_script}"
jid_dep="${first_dependency}"
for job in $(seq 1 "${n_jobs}"); do

    # add: --job-name "${job_name}" "${batch_script}" "${idx}"
    jid="$(sbatch --dependency="${dependency_code}:${jid_dep}" "${batch_script}" | awk '{print $4}')"
    echo "Submitted job ${job}/${n_jobs} with job id ${jid} and dependency ${jid_dep}"
    jid_dep="${jid}"

done
