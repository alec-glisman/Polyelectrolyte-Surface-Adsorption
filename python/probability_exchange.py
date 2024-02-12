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
from tqdm.auto import tqdm

# matplotlib settings
plt.rcParams["axes.formatter.use_mathtext"] = True
plt.rcParams["font.family"] = "serif"
plt.rcParams["font.serif"] = "cmr10"

# global variables
VERBOSE: bool = True
MOVING_AVERAGE_WINDOW: int = 1000  # each exchange attempt every 4 ps


class ParseGmxLog:
    """
    A class for parsing Gromacs log files and extracting exchange probabilities

    Attributes:
        f_log (Path): Path to the log file.
        text (str): Content of the log file.
        n_replica (int): Number of replicas in the simulation.
        t_final (float): Final simulation time in ns.
        df_repl_pr (pd.DataFrame): Exchange probabilities at each step.
        df_repl_pr_summary (pd.DataFrame): Average exchange probabilities.
    """

    def __init__(self, f_log: Path):
        """
        Initialize the ParseGmxLog object.

        Args:
            f_log (Path): Path to the log file.

        Raises:
            TypeError: If f_log is not a Path object.
            FileNotFoundError: If f_log does not exist or is a directory.
            TypeError: If f_log is not a .log file.
        """
        if not isinstance(f_log, Path):
            raise TypeError(f"Expected Path, got {type(f_log).__name__}")
        if not f_log.exists() or not f_log.is_file():
            raise FileNotFoundError(f"File not found: {f_log}")
        if not f_log.is_file():
            raise FileNotFoundError(f"Expected file, got directory: {f_log}")
        if f_log.suffix != ".log":
            raise TypeError(f"Expected .log file, got {f_log.suffix}")

        self.f_log = f_log
        self.name = f_log.name.split(".log")[0]
        self.text = f_log.read_text()

        self.n_replica = self._parse_n_replica()
        self.t_initial, self.t_final = self._parse_t_min_max()
        self.df_repl_pr = self.exchange_probabilities()
        self.df_repl_pr_summary = self.exchange_probabilities_summary()

    def _parse_n_replica(self) -> int:
        """
        Parse the number of replicas from the log file.

        The number of replicas is given in the log file in the form
        Repl  There are 8 replicas:
        We can extract the number of replicas by searching for the string
        "There are" and then extracting the integer that follows.

        Returns:
            int: Number of replicas.
        """
        # search for string
        n_replica = re.findall(r"(?<=Repl  There are )\d+", self.text)

        # check that only one match was found
        if len(n_replica) != 1:
            # if all replica numbers are the same, no error
            n_replica_guesses = [int(x) for x in n_replica]
            if len(set(n_replica_guesses)) != 1:
                raise ValueError(f"Expected 1 match, got {len(set(n_replica))}")

        # convert to integer
        n_replica = int(n_replica[0])

        return n_replica

    def _parse_t_min_max(self) -> tuple[float, float]:
        """
        Parse the final simulation time from the log file.

        The final simulation time is given in the log file in the form
        Replica exchange at step 17000 time 34.00000
        We can extract the final simulation time by searching for the string
        "time" and then extracting the float that follows.

        Returns:
            tuple: Minimum and maximum simulation times in ns.
        """
        times = re.findall(r"(?<=time\s)\d+.\d+", self.text)
        times = [float(x) for x in times]

        try:
            tf = max(times) / 1000.0
        except ValueError:
            tf = np.nan

        try:
            t0 = min(times) / 1000.0
        except ValueError:
            t0 = np.nan

        return t0, tf

    def _parse_repl_pr(self, line: str) -> list[float]:
        """
        Parse exchange probabilities from a single line of text. Exchanges are
        only attempted between neighboring replicas, so the exchange
        probabilities are only given for the even or odd replicas. This
        function places np.nan values between the exchange probabilities
        to account for this.

        Output is a list of exchange probabilities in the form
            P(0<->1), P(1<->2), ..., P(n-2<->n-1), P(n-1<->n)

        Args:
            line (str): Line of text containing exchange probabilities in the
            form
                Repl pr        .52       .00       1.0
            or
                Repl pr   .00       .00       .00       .00

        Returns:
            list: List of exchange probabilities.
        """
        # remove alphabetic characters and leading/trailing whitespace
        line = re.sub(r"[a-zA-Z]", "", line).strip()
        # convert whitespace to comma
        line = re.sub(r"\s+", ",", line)

        # convert comma separated string to list of floats
        lst_float = []
        for val in line.split(","):
            try:
                lst_float.append(float(val))
            except ValueError:
                warnings.warn(f"ValueError: {val}")
                lst_float.append(-1)

        # place np.nan elements between list elements
        lst_pad = [np.nan] * len(lst_float)
        lst_complete = [x for pr in list(zip(lst_float, lst_pad)) for x in pr][:-1]

        # prepend and append to list if in example 1 of Args
        if len(lst_complete) != self.n_replica - 1:
            lst_complete = [np.nan] + lst_complete + [np.nan]

        # check that list is the same length as the number of replica exchanges
        if len(lst_complete) != self.n_replica - 1:
            raise ValueError(
                f"Expected {self.n_replica} values, got {len(lst_complete)}"
            )

        return lst_complete

    def exchange_probabilities(self) -> pd.DataFrame:
        """
        Parse exchange probabilities from the log file.

        Exchange probabilities are given in the log file in the form
        Repl pr        .52       .00       1.0
        or
        Repl pr   .00       .00       .00       .00
        We can extract the exchange probabilities by searching for the string
        "Repl pr" and then extracting the floats that follow.

        Returns:
            pd.DataFrame: Exchange probabilities at each step.
        """
        # search for string
        prob_txt = re.findall(r"(?<=Repl pr).*", self.text)

        # parse exchange probabilities from each line
        prob_flt = []
        for line in prob_txt:
            prob_flt.append(self._parse_repl_pr(line))

        # convert to pandas data frame
        cols = [f"{i}-{i+1}" for i in range(self.n_replica - 1)]
        return pd.DataFrame(prob_flt, columns=cols)

    def exchange_probabilities_summary(self) -> pd.DataFrame:
        """
        Calculate the average exchange probability for each replica pair.

        Returns:
            pd.DataFrame: Average exchange probabilities.
        """
        if self.df_repl_pr is None:
            self.df_repl_pr = self.exchange_probabilities()
        return pd.DataFrame(self.df_repl_pr.describe().round(3))

    def save(self, dir_out: Path = None):
        """
        Save class attributes to files.

        Args:
            dir_out (Path): Path to output directory. Defaults to None.
        """
        if dir_out is None:
            dir_out = self.f_log.parents[1] / "analysis" / self.name

        dir_out.mkdir(parents=True, exist_ok=True)

        self.df_repl_pr.to_csv(dir_out / "exchange_probability_dynamics.csv")
        self.df_repl_pr_summary.to_csv(dir_out / "exchange_probability_summary.csv")

        f_out = dir_out / "exchange_probability_average.txt"
        try:
            avgs = self.df_repl_pr.mean().round(3)
            stds = self.df_repl_pr.std().round(3)
        except TypeError:
            avgs = pd.Series([np.nan] * (self.n_replica - 1))
            stds = pd.Series([np.nan] * (self.n_replica - 1))

        with open(f_out, "w", encoding="utf-8") as f:
            f.write(f"Datetime: {datetime.datetime.now()}\n")
            f.write(f"Log file: {self.f_log}\n\n")

            f.write(f"Number of replicas: {self.n_replica}\n")
            f.write(f"Initial time: {self.t_initial:.1f} ns\n")
            f.write(f"Final time: {self.t_final:.1f} ns\n")
            f.write(f"Simulation time: {self.t_final - self.t_initial:.1f} ns\n\n")

            f.write(f"Minimum exchange probability: {avgs.min():.2f}\n")
            f.write(f"Average exchange probability: {avgs.mean():.2f}\n")
            f.write(f"Std Dev exchange probability: {avgs.std():.2f}\n\n")

            f.write(
                f"Sorted Average Exchange Probabilities: \n{avgs.sort_values()}\n\n"
            )

            f.write("Average +- Std Dev Exchange Probabilities:\n")
            for i in range(self.n_replica - 1):
                f.write(f"{i}-{i+1}: {avgs.iloc[i]:.2f} {stds.iloc[i]:.2f}\n")
            f.write("\nStatistics:\n")
            f.write(self.df_repl_pr_summary.round(3).to_string())

    def plt_repl_pr_moving_average(self, window: int = 25, dir_out: Path = None):
        """
        Plot exchange probabilities with moving average.

        Args:
            window (int, optional): Window size for moving average.
            Defaults to 25.
            dir_out (Path, optional): Path to output directory.
            Defaults to None.
        """
        if dir_out is None:
            dir_out = self.f_log.parents[1] / "analysis" / self.name
        dir_out.mkdir(parents=True, exist_ok=True)

        data = (
            self.df_repl_pr.reset_index(drop=True).rolling(window, min_periods=1).mean()
        )
        times = re.findall(r"(?<=time\s)\d+.\d+", self.text)
        times = np.array([float(x) / 1000.0 for x in times])
        # sort curve and times by time
        idx_sort = np.argsort(times)

        # plot horizontal line at 0.3
        fig, ax = plt.subplots()
        ax.axhline(0.3, color="k", linewidth=2.0, alpha=1.0)
        ax.axhline(0.2, color="k", linewidth=2.0, alpha=1.0)

        # set colorblind friendly colormap
        cmap = plt.get_cmap("tab10")
        ax.set_prop_cycle(color=[cmap(i) for i in range(self.n_replica - 1)])

        for i in range(self.n_replica - 1):
            curve = data.iloc[:, i]
            ax.plot(
                times[idx_sort],
                curve[idx_sort],
                linewidth=2.5,
                alpha=1.0,
                label=f"{i}-{i+1}",
            )

        # set axis labels
        ax.set_xlabel("Time [ns]", fontsize=18, labelpad=10)
        ax.set_ylabel("(Rolling) Exchange Probability", fontsize=18, labelpad=10)
        ax.set_ylim(0, 1)
        ax.tick_params(axis="both", which="major", labelsize=16)
        ax.legend(loc="upper left", ncol=2, fontsize=14)
        ax.set_title(
            f"Window = {window}, Count = {len(data)}",
            fontsize=18,
            pad=10,
        )

        # save figure
        fig.tight_layout()
        fig.savefig(dir_out / "exchange_probability_dynamics.png", dpi=600)
        plt.close(fig)


def find_logs(dr: Path) -> list[Path]:
    """
    Find all log files in the given directory matching internal pattern.

    Args:
        dr (Path): Path to directory containing log files.

    Returns:
        list: List of log files.
    """
    log_files = sorted(list(Path(dr).rglob("**/replica_00/prod_*.log")))
    return log_files


def main(verbose: bool = False) -> None:
    """
    Main function for parsing log files and extracting exchange probabilities.

    Args:
        verbose (bool, optional): Print output to terminal. Defaults to False.

    Returns:
        None

    """

    # Input data path
    d_data = Path(__file__).parents[1] / "data"

    # Find all log files in the current directory
    f_logs = find_logs(d_data)
    if verbose:
        print(f"Found {len(f_logs)} log files in {d_data}")

    # Parse log files and extract exchange probabilities
    for idx, log_file in tqdm(
        enumerate(f_logs),
        desc="Parsing log files",
        dynamic_ncols=True,
        total=len(f_logs),
    ):
        print(f"Reading log file {idx+1}/{len(f_logs)}: {log_file}")
        try:
            log = ParseGmxLog(log_file)
        except ValueError as e:
            warnings.warn(f"ValueError: {e}")
            continue

        log.save()
        log.plt_repl_pr_moving_average(window=MOVING_AVERAGE_WINDOW)

        # output probabilities to terminal
        if verbose:
            print("Average Exchange probabilities" + f" (tf = {log.t_final:.1f} ns):")
            print(log.df_repl_pr_summary.to_string())
            print()

    # for f_logs with same Path.parents[1] (i.e. same simulation), combine into one file
    d_logs_combined = []
    for f_log in f_logs:
        if f_log.parents[1] not in d_logs_combined:
            d_logs_combined.append(f_log.parents[1])

    for d_log in tqdm(d_logs_combined, desc="Combining log files", dynamic_ncols=True):
        f_logs_combined = find_logs(d_log)

        # make output file that is all log files combined
        d_out = d_log / "analysis" / "combined"
        f_out = d_out / "combined.log"
        f_out.parent.mkdir(parents=True, exist_ok=True)

        print(f"Writing combined log file: {f_out.relative_to(d_data)}")
        with open(f_out, "w", encoding="utf-8") as f:
            for f_log in f_logs_combined:
                f.write(f_log.read_text())

        # parse combined log file
        log = ParseGmxLog(f_out)
        log.save(dir_out=d_out)
        log.plt_repl_pr_moving_average(window=MOVING_AVERAGE_WINDOW, dir_out=d_out)


if __name__ == "__main__":
    main(verbose=VERBOSE)
