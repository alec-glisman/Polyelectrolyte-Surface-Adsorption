"""This script calculates the frame nearest the average of a xvg file for
percentile data used.
"""
import argparse
import os
import subprocess
from pathlib import Path


def load_data(xvg_filename):
    """Loads data from an xvg file.

    Args:
        xvg_filename(str): The path to the xvg file.

    Returns:
        tuple(list(float)): The list of numbers(for first two columns) in the
            xvg file.
    """
    xd = []
    yd = []

    with open(xvg_filename, "r", encoding="utf-8") as fd:
        for line in fd:
            cols = line.split()

            # Ignore xvg header
            if ("@" in cols[0]) or ("#" in cols[0]):
                continue

            xd.append(float(cols[0]))
            yd.append(float(cols[1]))

    return (xd, yd)


def mean(lst, percentile=0.0):
    """Calculates the mean of the last percentile of a list of numbers.

    Args:
        lst(list(float)): The list of numbers.
        percentile(float): The percentile to use. Defaults to 0.0.

    Returns:
        float: The mean of the list.
    """
    num_idxs = len(lst)
    first_idx = int(num_idxs * percentile)
    lst = lst[first_idx:]
    return sum(lst) / len(lst)


def closest_float_idx(lst, value):
    """Finds the closest value in a list of numbers.

    Args:
        lst(list(float)): The list of numbers.
        value(float): The value to search for.

    Returns:
        float: The closest value in the list.
    """
    min_value = min(lst, key=lambda x: abs(x - value))
    min_idx = lst.index(min_value)
    return min_idx


def choose_closest_frame(xvg_filename, percentile=0.0):
    """Chooses the closest frame to the average of the xvg file.

    Args:
        xvg_filename(str): The path to the xvg file.
        percentile(float): The percentile to use. Defaults to 0.0.

    Returns:
        float: The simulation time at the closest frame.
    """
    (time, dat) = load_data(xvg_filename)
    dat_avg = mean(dat, percentile)
    dat_closest_idx = closest_float_idx(dat, dat_avg)
    return time[dat_closest_idx]


def dump_gro_frame(xtc_filename, gro_filename, time):
    """Dumps a frame from a gro file.

    Args:
        xtc_filename(str): The path to the input xtc file.
        gro_filename(str): The path to the output gro file.
        time(float): The time to dump[ps].
    """
    std_in = "System\nSystem\n"
    cmd = [
        "gmx",
        "-nocopyright",
        "-quiet",
        "trjconv",
        "-f",
        xtc_filename,
        "-s",
        f"{Path(xtc_filename).with_suffix('')}.tpr",
        "-o",
        gro_filename,
        "-dump",
        str(time),
    ]

    subprocess.run(
        cmd,
        env=os.environ.copy(),
        input=std_in.encode("utf=8"),
        check=True,
    )


def main(xvg_filename, xtc_filename, gro_filename, percentile=0.0):
    """Main function.

    Args:
        xvg_filename(str): The path to the xvg file.
        xtc_filename(str): The path to the xtc file.
        gro_filename(str): The path to the gro file.
        percentile(float): The percentile to use. Defaults to 0.0.
    """
    time = choose_closest_frame(xvg_filename, percentile=percentile)
    dump_gro_frame(xtc_filename, gro_filename, time)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="This script calculates the frame nearest"
        + "the average of a xvg file for percentile data used"
    )
    parser.add_argument(
        "-x",
        "--xvg_filename",
        type=str,
        required=True,
        help="The path to the input xvg file",
        metavar="xvg_filename",
    )
    parser.add_argument(
        "-t",
        "--xtc_filename",
        type=str,
        required=True,
        help="The path to the input xtc trajectory file",
        metavar="xtc_filename",
    )
    parser.add_argument(
        "-g",
        "--gro_filename",
        type=str,
        required=True,
        help="The path to the output gro file",
        metavar="gro_filename",
    )
    parser.add_argument(
        "-p",
        "--percentile",
        type=float,
        required=True,
        help="The percentile to use for data in statistics",
        metavar="percentile",
    )
    args = parser.parse_args()

    main(
        args.xvg_filename,
        args.xtc_filename,
        args.gro_filename,
        args.percentile,
    )
