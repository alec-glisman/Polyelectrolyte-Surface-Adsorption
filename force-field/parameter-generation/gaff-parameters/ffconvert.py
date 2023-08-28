import argparse
from pathlib import Path
import parmed as pmd
import shutil


# read the command line arguments
parser = argparse.ArgumentParser()
parser.add_argument("filename", help="The name of the file to convert")
args = parser.parse_args()
fname = args.filename

# Find the Amber force field files
amber = pmd.load_file(f"{fname}.prmtop", f"{fname}.inpcrd")

# make output directory
output = "parmed"
Path(output).mkdir(parents=True, exist_ok=True)


# Save the GROMACS force field files
amber.save(f"{output}/{fname}.top")
amber.save(f"{output}/{fname}.gro")

# copy .csv and .pdb files
shutil.copy(f"charges.csv", f"{output}/{fname}-resp-charges.csv")
shutil.copy(f"{fname}.pdb", f"{output}/{fname}.pdb")
