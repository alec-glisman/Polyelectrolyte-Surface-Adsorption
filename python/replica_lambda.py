"""
Generate lambda values for replica exchange simulation.
Lambda values are generated according to the following formula:
lambda_i = temp_unbiased / temp_i
where temp_i is the temperature of i-th replica.

Usage
-----
python replica_lambda.py --n_replica 32 --tmin 300 --tmax 440 --temp_unbiased 300

Parameters
----------
n_replica : int
    Number of replicas.
tmin : float
    Minimum temperature in Kelvin.
tmax : float
    Maximum temperature in Kelvin.
temp_unbiased : float
    Temperature in Kelvin of unbiased simulation.
"""

import argparse
import numpy as np


def replica_temperatures(
    n_replica: int, temp_min: float, temp_max: float
) -> np.ndarray:
    """Generate temperatures for replica exchange simulation.
    Temperatures are geometrically distributed between temp_min and temp_max
    according to the following formula:
    T_i = T_min * (T_max / T_min) ^ (i / (n_replica - 1))
    where i is the index of replica.

    Parameters
    ----------
    n_replica : int
        Number of replicas.
    temp_min : float
        Minimum temperature.
    temp_max : float
        Maximum temperature.

    Returns
    -------
    List[float]
        List of temperatures.

    """
    idx = np.arange(n_replica)
    return temp_min * (temp_max / temp_min) ** (idx / (n_replica - 1))


def replica_lambdas(temp_unbiased: float, temps: np.ndarray) -> np.ndarray:
    """Generate lambda values for replica exchange simulation.
    Lambda values are generated according to the following formula:
    lambda_i = temp_unbiased / temp_i
    where temp_i is the temperature of i-th replica.

    Parameters
    ----------
    temp_unbiased : float
        Temperature of unbiased simulation.
    temps : np.ndarray
        List of temperatures for all replicas.

    Returns
    -------
    np.ndarray
        List of lambda values for all replicas.
    """
    return temp_unbiased / temps


def main() -> None:
    """Main function."""
    parser = argparse.ArgumentParser(
        description="Generate lambda values for replica exchange simulation."
    )
    parser.add_argument(
        "--n_replica",
        "-n",
        type=int,
        default=6,
        help="Number of replicas.",
    )
    parser.add_argument(
        "--tmin",
        type=float,
        default=300,
        help="Minimum temperature in Kelvin.",
    )
    parser.add_argument(
        "--tmax",
        type=float,
        default=370,
        help="Maximum temperature in Kelvin.",
    )
    parser.add_argument(
        "--tunbiased",
        type=float,
        default=300,
        help="Temperature in Kelvin of unbiased simulation.",
    )
    args = parser.parse_args()

    if args.tmin <= 0:
        raise ValueError("tmin must be greater than 0.")
    if args.tmax <= 0:
        raise ValueError("tmax must be greater than 0.")
    if args.tunbiased <= 0:
        raise ValueError("temp_unbiased must be greater than 0.")
    if args.tmin >= args.tmax:
        raise ValueError("tmin must be less than tmax.")
    temps = replica_temperatures(args.n_replica, args.tmin, args.tmax)
    lambdas = replica_lambdas(args.tunbiased, temps)
    print(" i     temp_i lambda_i")
    for i, temp, lam in zip(range(args.n_replica), temps, lambdas):
        print(f"{i:02} {temp:0.6f} {lam:0.6f}")


if __name__ == "__main__":
    main()
