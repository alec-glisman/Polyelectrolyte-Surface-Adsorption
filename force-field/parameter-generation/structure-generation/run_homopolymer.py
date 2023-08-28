"""This script generates smiles for a polymer based on the monomers and
stereochemistries. 

The monomers and stereochemistries should be in the same order and are
limited to the groups in the dictionaries located the generator class.
The n_termius and c_termius also must be found in the cap_dict. 

The function will also output the smiles to a file called smiles.txt.

Note that `rdkit` is required to run this script.

Author: Alec Glisman
Date: April 20th, 2023


Example
-------
    To run the script, simply run the following command in the terminal:
        $ python run.py
"""

# imports
from polymer_generator import TextPolymer
from tqdm import tqdm

# main method
if __name__ == "__main__":
    # polymer building blocks
    monomers = ["acrylate", "acrylate_ion", "acetate", "alcohol"]
    lengths = [2, 3, 5, 8, 16, 32]

    # polymer chains
    polymers, fnames = [], []
    for length in lengths:
        for monomer in monomers:
            if monomer == "acetate":
                id = "Ace"
            elif monomer == "alcohol":
                id = "Alc"
            elif monomer == "acrylate_ion":
                id = "Acr"
            elif monomer == "acrylate":
                id = "Acn"
            else:
                raise ValueError(f"Monomer {monomer} not found in dictionary.")
            
            fnames.append(f"P{id}-{length}mer-atactic-Hend")
            polymers.append([monomer] * length)

    # alpha carbon stereochemistry
    stereochemistry = [
        # 1-4
        "d",
        "l",
        "l",
        "d",
        # 5-8
        "d",
        "l",
        "d",
        "d",
        # 9-12
        "l",
        "l",
        "l",
        "d",
        # 13-16
        "l",
        "d",
        "d",
        "l",
        # 17-20
        "d",
        "d",
        "d",
        "l",
        # 21-24
        "l",
        "d",
        "l",
        "l",
        # 25-28
        "l",
        "d",
        "d",
        "d",
        # 29-32
        "d",
        "l",
        "l",
        "l",
    ]

    # generate smiles and pdb files
    for polymer, fname in tqdm(
        zip(polymers, fnames),
        total=len(polymers),
        desc="Generating Smiles",
        colour="green",
        unit="polymer",
    ):
        # trim stereochemistry to match polymer length
        stereo = stereochemistry[: len(polymer)]
        assert len(polymer) == len(
            stereo
        ), "Error: polymer and stereochemistry must be the same length"

        # generate polymer
        tp = TextPolymer(polymer, stereo)
        tp.smiles(save_file="smiles.txt")
        try:
            tp.pdb(save_file=f"{fname}.pdb")
        except ValueError as exc:
            print(f"Error: {fname} failed to generate pdb file")
            print(f"Error: polymer: {polymer}")
            print()
            raise exc
