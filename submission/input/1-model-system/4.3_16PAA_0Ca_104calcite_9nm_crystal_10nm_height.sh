#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Author     : Alec Glisman (GitHub: @alec-glisman)
# Date       : 2023-08-30
# Description: Script to set global variables and preferences for the simulation.
# Notes      : Script should only be called from the main run.sh script.

# Hardware ####################################################################

export CPU_THREADS='16' # number of CPU threads to use (-1 = all available)
export PIN_OFFSET='0'   # offset for CPU thread pinning (-1 = no offset)
export GPU_IDS='0'      # GPU device(s) to use (0 = first GPU, 01 = first two GPUs)

# System components ###########################################################

# statistical mechanics
export PRODUCTION_ENSEMBLE='NVT' # {NVT, NPT}
export TEMPERATURE_K='300'       # temperature in Kelvin
export PRESSURE_BAR='1'          # pressure in bar

# integration
export INTEGRATION_NS='500' # [ns] final simulation time for production run {100, 500}

# polyelectrolyte chemistry
export MONOMER="Acr" # Dominant monomer: {Acr, Acn, Asp, Glu, Ace, Alc}
export BLOCK=""      # Block copolymer: {iiia, iiiiiiia, iiic, iiiiiic} for {Acr, Acn}

# calcium carbonate crystal surface
export CRYSTAL="calcite" # {calcite, aragonite, vaterite}
export SURFACE="104"     # Miller index of crystal surface {104, 001}

# system size
export SURFACE_SIZE='9'     # size of crystal surface in nm {3, 5, 8, 9, 10, 11, 12, 13}
export BOX_HEIGHT='10'      # height of simulation box in nm
export PDB_BULK_ZMIN='4.62' # z-coordinate of bottom of bulk part of crystal in nm in PDB file
export PDB_BULK_ZMAX='5.09' # z-coordinate of top of bulk part of crystal in nm in PDB file

# number of each component
export N_MONOMER='16'  # number of monomers in chain {1, 2, 5, 8, 16, 32}
export N_CHAIN='1'     # number of chains
export N_CARBONATE='0' # number of aqueous carbonate ions
export N_SODIUM='16'   # number of aqueous sodium ions
export N_CALCIUM='0'   # number of aqueous calcium ions
export N_CHLORINE='0'  # number of aqueous chlorine ions

# tag for system
export TAG_JOBID="1.4.3" # tag to append to system name

# Enhanced sampling ###########################################################

# hamiltonian replica exchange
export HREMD_N_REPLICA='32' # number of replicas in HREMD simulations
export HREMD_N_STEPS='1000' # number of steps between replica exchange attempts

# OneOPES replica exchange
export ONEOPES_N_REPLICA='8'  # number of replicas in OneOPES simulations
export ONEOPES_N_STEPS='1000' # number of steps between replica exchange attempts

# well-tempered metadynamics
export METAD_BIASFACTOR='8'       # bias factor for C.V. effective temperature
export METAD_HEIGHT='1.0'         # [kJ/mol] initial height of Gaussians (kT = 2.48 kJ/mol at 298 K)
export METAD_SIGMA='0.025'        # width of Gaussians, set to 0.33–0.5 of estimated fluctuation
export METAD_GRID_SPACING='0.005' # width of bins in the meta-dynamics grid
export METAD_GRID_MIN='0'         # minimum grid point for Gaussian deposition
export METAD_GRID_MAX='10'        # maximum grid point for Gaussian deposition
export METAD_PACE='500'           # [steps] between deposition of Gaussians

# harmonic restraints
export PE_WALL_MIN='0.3'      # z-coordinate of lower wall in nm
export PE_WALL_MAX='4.0'      # z-coordinate of upper wall in nm
export PE_WALL_MAX_EQBM='2.0' # z-coordinate of upper wall in nm during equilibration
export ATOM_REFERENCE='7310'  # atom number of reference atom for harmonic restraints (1 = first atom)
export ATOM_OFFSET='-0.305'   # z-coordinate offset of reference atom from crystal surface in nm
