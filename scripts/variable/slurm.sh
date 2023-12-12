#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-09-06
# Description: Script to set max walltime for mdrun based on SLURM walltime
# Notes      : Script should only be called from the main run.sh script.

# #######################################################################################
# Find SLURM Walltime ###################################################################
# #######################################################################################

# Find walltime remaining
if [[ -n "${SLURM_JOB_ID+x}" ]]; then
    echo "SLURM_JOB_ID is set to '${SLURM_JOB_ID}'"
    # Slurm find walltime remaining, return in format DD-HH:MM:SS
    walltime_remaining="$(squeue -j "${SLURM_JOB_ID}" -h -o '%L')"
    echo "walltime_remaining: ${walltime_remaining}"

    # > 1 day walltime remaining
    if [[ "${walltime_remaining}" == *-* ]]; then
        walltime_remaining_days="$(echo "${walltime_remaining}" | awk -F- '{print $1}')"
        walltime_remaining_hours="$(echo "${walltime_remaining}" | awk -F- '{print $2}' | awk -F: '{print $1}')"
        walltime_remaining_minutes="$(echo "${walltime_remaining}" | awk -F- '{print $2}' | awk -F: '{print $2}')"
        total_walltime_remaining_hours="$(bc -l <<<"scale=2; (${walltime_remaining_days}*24)+${walltime_remaining_hours}+(${walltime_remaining_minutes}/60)")"
        echo "walltime_remaining_days: ${walltime_remaining_days}"
        echo "walltime_remaining_hours: ${walltime_remaining_hours}"
        echo "walltime_remaining_minutes: ${walltime_remaining_minutes}"
        echo "total_walltime_remaining_hours: ${total_walltime_remaining_hours}"

    # < 1 day walltime remaining
    elif [[ "${walltime_remaining}" == *:*:* ]]; then
        echo "WARNING: Less than 1 day walltime remaining"
        walltime_remaining_hours="$(echo "${walltime_remaining}" | awk -F: '{print $1}')"
        walltime_remaining_minutes="$(echo "${walltime_remaining}" | awk -F: '{print $2}')"
        total_walltime_remaining_hours="$(bc -l <<<"scale=2; ${walltime_remaining_hours}+(${walltime_remaining_minutes}/60)")"
        echo "walltime_remaining_hours: ${walltime_remaining_hours}"
        echo "walltime_remaining_minutes: ${walltime_remaining_minutes}"
        echo "total_walltime_remaining_hours: ${total_walltime_remaining_hours}"

    # < 1 hour walltime remaining
    elif [[ "${walltime_remaining}" == *:* ]]; then
        echo "WARNING: Less than 1 hour walltime remaining"
        exit

    else
        total_walltime_remaining_hours="$(echo "${walltime_remaining}" | awk -F: '{print $1}')"
    fi

    # subtract 0.2 hours for safety
    mdrun_runtime_hours="$(bc -l <<<"scale=2; ${total_walltime_remaining_hours}-0.2")"
else
    # No walltime limit
    mdrun_runtime_hours='16'
fi

# export mdrun runtime in hours
export WALLTIME_HOURS="${mdrun_runtime_hours}"
