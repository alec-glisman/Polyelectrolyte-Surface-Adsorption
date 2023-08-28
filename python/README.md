# Python (helper) files

The [`python`](./../python) directory contains Python files that aid in the simulation pipeline.
These are called by the [`scripts`](./../scripts).

- [`mean_frame_xvg_2_col.py`](./mean_frame_xvg_2_col.py): A script to calculate the mean of a subset of frames from a 2 column `.xvg` file. This is used to calculate the average density from an NPT simulation and pick a frame that is closest to the average density for future NVT simulations.
- [`setup_umbrella.sh`](./setup_umbrella.sh): A modified version of a file Justin Lemkul provided in a tutorial.
This will generate the input files for an umbrella sampling simulation.
The input is a "pull" file where the collective variable has been varied using a steered-MD approach.
The script then generates N independent windows (simulations) for the range of the collective variable.
