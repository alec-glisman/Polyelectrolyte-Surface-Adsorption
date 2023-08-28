import numpy as np
from pathlib import Path
import pandas as pd
import warnings

# constants
IDX: int = 2
N_MONOMER: int = 1
INPUT_DIRS: list[str] = [
    "output/PAce-1mer-atactic-Hend_HF_6-31G_ExtremeSCF_RESP",
    "output/PAlc-1mer-atactic-Hend_HF_6-31G_ExtremeSCF_RESP",
    "output/PAcr-1mer-atactic-Hend_HF_6-31G_ExtremeSCF_RESP",
    "output/PAcn-1mer-atactic-Hend_HF_6-31G_ExtremeSCF_RESP",
]

if __name__ == "__main__":
    # formatting
    pd.options.display.float_format = "{:,.3f}".format

    INPUT_DIR: str = INPUT_DIRS[IDX]

    # find all .molden.chg files in directory tree
    files = list(Path(INPUT_DIR).rglob("*.molden.chg"))
    # get parent directory name of each file
    dirs = [f.parent.stem for f in files]

    print(f"Found {len(files)} files")

    # load all files into dataframe
    molden = None
    for file, dr in zip(files, dirs):
        try:
            df = pd.read_csv(
                file,
                delim_whitespace=True,
                names=["atom", "x", "y", "z", "charge"],
                dtype={
                    "atom": str,
                    "x": float,
                    "y": float,
                    "z": float,
                    "charge": float,
                },
                header=None,
            )
        except ValueError:
            warnings.warn(f"Error reading file {file}")
            with open(f"{INPUT_DIR}/warnings.log", "+a", encoding="utf-8") as f:
                f.write(f"Error reading file {file}\n")
            continue

        # calculate partial sum of charges for each atom
        df["id"] = df.index.copy()
        df["charge_cumsum"] = df["charge"].cumsum()
        df["stereochemistry"] = dr
        # get residue id for each atom
        n_atom_per_monomer = (len(df) - 2) // N_MONOMER
        resid = np.zeros(len(df), dtype=int)
        if N_MONOMER == 1:
            resid[:] = 1
        elif N_MONOMER == 3:
            resid[: (n_atom_per_monomer + 1)] = 1
            resid[(n_atom_per_monomer + 1) : (2 * n_atom_per_monomer + 1)] = 2
            resid[(2 * n_atom_per_monomer + 1) :] = 3
        df["resid"] = resid
        if "carbonate" in INPUT_DIR:
            df["resid"] = 1

        # append to molden dataframe
        if molden is None:
            molden = df
        else:
            molden = pd.concat([molden, df], ignore_index=True)

    # save molden dataframe to csv
    molden.to_csv(f"{INPUT_DIR}/molden_all_data.csv", index=False)

    # average charges for each atom across all stereochemistries
    molden_avg = molden.groupby("id").agg(
        {"atom": "first", "resid": "first", "charge": "mean"}
    )
    molden_avg["charge_cumsum"] = molden_avg["charge"].cumsum()

    # calculate net charge on each residue
    molden_agg = molden_avg.groupby("resid").agg({"charge": "sum", "resid": "count"})
    molden_agg.rename(columns={"resid": "n_atom"}, inplace=True)
    molden_agg.to_csv(f"{INPUT_DIR}/molden_avg_per_monomer.csv", index=True)
    print(molden_agg)

    # subtract mean charge of each residue from its atoms
    stereo_charge = molden_avg["charge"].copy()
    if ("paai" in INPUT_DIR) or ("PAcr" in INPUT_DIR):  # if paai, each residue should have -1 charge
        residue_charges = molden_agg["charge"] + 1
    elif "carbonate" in INPUT_DIR:  # if carbonate, each residue should have -2 charge
        residue_charges = molden_agg["charge"] + 2
    else:
        residue_charges = molden_agg["charge"]
    molden_avg["charge"] = molden_avg["charge"] - molden_avg["resid"].map(
        residue_charges / molden_agg["n_atom"]
    )
    molden_avg["charge_cumsum"] = molden_avg["charge"].cumsum()

    # verify the net charge on each residue is zero
    molden_agg = molden_avg.groupby("resid").agg({"charge": "sum"})
    molden_agg.to_csv(
        f"{INPUT_DIR}/molden_avg_per_monomer_mean_removed.csv", index=True
    )
    print(molden_agg)

    # full electrostatic partial charges
    output = pd.DataFrame(
        {
            "atomid": molden_avg.index.copy() + 1,
            "atom": molden_avg["atom"],
            "resid": molden_avg["resid"],
            "stereo_charge": stereo_charge,
            "full_charge": molden_avg["charge"],
            "scaled_charge": molden_avg["charge"] * 0.7500,
        }
    )
    output.to_csv(f"{INPUT_DIR}/charges.csv", index=False, sep=",")
    print(output)

    # save molden dataframe to csv
    output_minimal = output[["atomid", "atom", "scaled_charge"]]
    output_minimal.to_csv(f"{INPUT_DIR}/output.csv", index=False)
