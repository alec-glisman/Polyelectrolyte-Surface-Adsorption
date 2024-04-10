import numpy as np


def conv_hex_to_cubic_idx(hex_idx: np.ndarray) -> np.ndarray:
    """
    Converts a hexagonal Miller index to a cubic Miller index.

    Parameters
    ----------
    hex_idx : np.ndarray
        Hexagonal Miller index.

    Returns
    -------
    np.ndarray
        Cubic Miller index.

    Raises
    ------
    ValueError
        If the input hexagonal Miller index does not have 4 elements.
    """
    if len(hex_idx) != 4:
        raise ValueError("Hexagonal Miller index must have 4 elements.")

    return np.array([hex_idx[0], hex_idx[1], hex_idx[3]])
