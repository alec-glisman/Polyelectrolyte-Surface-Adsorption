#!/usr/bin/env bash
# -*- coding: utf-8 -*-

n_jobs='5'
first_dependency='1'
dependency_code='afterany'
batch_script='2md_4.sh'
idx='6'
job_name='4.7-md'

# iterate over all jobs
echo "Submitting ${n_jobs} jobs with script ${batch_script}"
jid_dep="${first_dependency}"
for job in $(seq 1 "${n_jobs}"); do

    jid="$(sbatch --dependency="${dependency_code}:${jid_dep}" --job-name "${job_name}" "${batch_script}" "${idx}" | awk '{print $4}')"
    echo "Submitted job ${job}/${n_jobs} with job id ${jid} and dependency ${jid_dep}"
    jid_dep="${jid}"

done
