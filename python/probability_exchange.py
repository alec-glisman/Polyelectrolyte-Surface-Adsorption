"""
This file parses gmx mdrun log files and extracts the exchange probabilities
between neighboring replicas. It then outputs the exchange probabilities in a
txt file.

:Author: Alec Glisman (GitHub: @alec-glisman)
:Date: 2022-10-10
:Copyright: 2022 Alec Glisman
"""

# Standard library
import datetime
from pathlib import Path
import re
import warnings

# Third-party imports
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


def find_logs(dr: Path) -> list[Path]:
    """
    Find all log files in the given directory matching internal pattern.

    Args:
        dr (Path): Path to directory containing log files.

    Returns:
        list: List of log files.
    """
    log_files = sorted(
        list(Path(dr).rglob("**/replica_00/nvt_hremd_*.log")))
    log_files.extend(sorted(
        list(Path(dr).rglob("**/replica_00/2-mdrun-output/nvt_hremd_*.log"))))
    return log_files


def parse_probabilities(f_log: Path) -> pd.DataFrame:
    """
    Load text file and parse exchange probabilities

    Args:
        f_log (Path): Input gmx mdrun log file

    Returns:
        pd.DataFrame: Exchange probabilities at each step
    """

    # parse text file and extract exchange probabilities
    text = f_log.read_text()
    prob_txt = re.findall(r"(?<=Repl pr).*", text)
    prob_flt = []
    tf = []

    # prepare data for numpy array
    for i in range(len(prob_txt)):

        # remove alphabetic characters
        prob_txt[i] = re.sub(r"[a-zA-Z]", "", prob_txt[i])

        # remove leading and trailing whitespace
        prob_txt[i] = prob_txt[i].strip()

        # convert whitespace to comma
        prob_txt[i] = re.sub(r"\s+", ",", prob_txt[i])

        # convert comma separated string to list of floats
        lst_float = []
        for val in prob_txt[i].split(","):
            try:
                x = float(val)
                lst_float.append(x)
            except ValueError:
                warnings.warn(f"ValueError: {val}")
                # lst_float.append(np.nan)

        lst_zeros = [np.nan] * len(lst_float)

        # place zero elements between non-zero elements
        lst_complete = [x for l in list(
            zip(lst_float, lst_zeros)) for x in l][:-1]

        # prepend and append to list if necessary
        if len(prob_flt) == 0:
            pass
        elif (len(lst_complete) != len(prob_flt[-1])):
            lst_complete = [np.nan] + lst_complete + [np.nan]

        # check that list is the same length as previous list
        if len(prob_flt) > 0:
            if len(lst_complete) != len(prob_flt[-1]):
                warnings.warn(
                    f"List length mismatch: {len(lst_complete)} vs {len(prob_flt[-1])}")
                continue

        # output results
        prob_flt.append(lst_complete)

    # calculate final simulation time
    times = re.findall(r"(?<=time\s)\d+.\d+", text)
    times = [float(x) for x in times]
    try:
        tf = max(times) / 1000.
    except ValueError:
        tf = np.nan

    # convert to pandas dataframe
    if len(prob_flt) > 0:
        idxs = range(len(prob_flt[0]))
        cols = [f"{i}-{i+1}" for i in idxs]
        return pd.DataFrame(prob_flt, columns=cols), tf
    else:
        return pd.DataFrame(), tf


plt.rcParams["axes.formatter.use_mathtext"] = True
plt.rcParams["font.family"] = "serif"
plt.rcParams["font.serif"] = "cmr10"


if __name__ == "__main__":
    # Input path
    d_data = f"{Path.cwd()}/data"

    # Find all log files in the current directory
    f_logs = find_logs(d_data)
    print(f"Found {len(f_logs)} log files")

    # Parse log files and extract exchange probabilities
    for (idx, log_file) in enumerate(f_logs):
        print(f"Reading log file {idx+1}/{len(f_logs)}: {log_file}")
        df, t = parse_probabilities(log_file)

        # calculate average exchange probability
        avg = pd.DataFrame(df.mean(axis=0))
        try:
            stats = pd.DataFrame(df.describe())
        except:
            stats = pd.DataFrame()

        # output probabilities to file
        if "prod" in log_file.stem:
            d_out = log_file.parents[1] / "analysis" / "replica_exchange"
        else:
            d_out = log_file.parents[1] / "analysis" / "replica_exchange"

        d_out.mkdir(parents=True, exist_ok=True)

        # output probabilities to terminal
        print(f"Output path: {d_out}")
        print(f"Average Exchange probabilities (tf = {t:.1f} ns):")
        print(avg.to_string(float_format="{:.2f}".format))
        print()

        f_out = d_out / "exchange_probability_dynamics.csv"
        df.to_csv(f_out)

        f_out = d_out / "exchange_probability_average.txt"
        with open(f_out, "w", encoding="utf-8") as f:
            # date and time
            f.write(f"Datetime: {datetime.datetime.now()}")
            f.write("\n\n")
            # exchange probabilities
            f.write(f"Average Exchange probabilities (tf: {t:.1f} ns):\n")
            f.write(avg.round(decimals=2).to_string(header=False))
            f.write("\n")
            f.write(f"Average of averages: {avg.mean().values[0]:.2f}\n")
            f.write(f"Standard deviation: {avg.std().values[0]:.2f}\n")
            # whitespace
            f.write("\n\n")
            # statistics
            f.write("Statistics:\n")
            f.write(stats.round(decimals=2).to_string())

        # convert probabilities to percentage
        avg *= 100
        avg = avg.round(0).astype(int)

        # continue loop if no data
        if len(avg) == 0:
            continue

        # output probabilities as table to file
        f_out = d_out / "exchange_probability_average.png"
        fig = plt.figure(figsize=(1.5, 7))
        ax = fig.add_subplot(111, frame_on=False)
        ax.axis("off")
        ax.axis("tight")
        ax.set_title(r"$t_f = $ " + f"{t:.1f} [ns]")
        ax.table(cellText=avg.values, rowLabels=avg.index,
                 colLabels=[r"$P(\mathrm{Exch.})$ [%]"],
                 fontsize=32, loc="center")
        fig.tight_layout()
        fig.savefig(f_out, dpi=600)
