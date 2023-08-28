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
    # polymer building blocks: {i: acrylate_ion, n: acrylate, a: acetate, c: alcohol}
    # homopolymer blocks
    block_iiii = ["acrylate_ion", "acrylate_ion", "acrylate_ion", "acrylate_ion"]
    block_nnnn = ["acrylate", "acrylate", "acrylate", "acrylate"]
    # 25% substitution copolymer blocks
    block_iiia = ["acrylate_ion", "acrylate_ion", "acrylate_ion", "acetate"]
    block_iiic = ["acrylate_ion", "acrylate_ion", "acrylate_ion", "alcohol"]
    block_nnna = ["acrylate", "acrylate", "acrylate", "acetate"]
    block_nnnc = ["acrylate", "acrylate", "acrylate", "alcohol"]

    # polymer chains
    polymers = [
        # 4mer homopolymer
        block_iiii * 1,
        block_nnnn * 1,
        # 4mer PAA(i) 25% substitution
        block_iiic * 1,
        block_iiia * 1,
        # 4mer PAA(n) 25% substitution
        block_nnnc * 1,
        block_nnna * 1,
    ]

    # filenames for data output
    fnames = [
        f"PAcr-4mer-atactic-Hend",
        f"PAcn-4mer-atactic-Hend",
        f"PAcr-iiic_block-4mer-atactic-Hend",
        f"PAcr-iiia_block-4mer-atactic-Hend",
        f"PAcn-iiic_block-4mer-atactic-Hend",
        f"PAcn-iiia_block-4mer-atactic-Hend",
    ]

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
