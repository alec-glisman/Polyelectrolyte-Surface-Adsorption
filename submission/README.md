# Computational Job Submission Files

The [`submission`](./../submission) directory contains files that are used to submit jobs to a cluster or workstation.
These files are essentially wrappers on the pipeline [`run`](./../scripts/run) script.
The files gather previous data from the [`data`](./../data) directory, pipeline global variables from the [`parameters`](./../parameters) directory, and call the pipeline script.

Files in this directory can be added/deleted/modified as needed.
Older scripts can be kept in the [`archive`](./archive) directory for future reference.

Files with the prefix `batch` are used to run jobs on a workstation or other computer where the user runs jobs directly (interactively) via the command line.
These scripts should be run from the command line as `./[file]`

Files with the prefix `sbatch` are used to run jobs on a cluster where the user submits jobs to a queueing system (e.g. SLURM).
These scripts should be run from the command line as `sbatch [file]`

Files with the prefix `submit` are used to run jobs on a cluster where the user submits jobs to a queueing system as well.
However, these scripts will submit multiple jobs to `sbatch` at once using the GNU `parallel` tool.
These scripts should be run from the command line as `./[file]`

Slurm helper submit files that take in global variables are placed in the [`slurm`](./slurm) directory.
Slurm output logs are placed in the [`logs`](./logs) directory.
The log files are often large and commonly deleted, so they are ignored by git.
