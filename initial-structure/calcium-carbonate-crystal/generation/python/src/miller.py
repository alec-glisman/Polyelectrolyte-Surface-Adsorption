def conv_hex_to_cubic_idx(hex_idx: tuple[int, int, int, int]) -> tuple[int, int, int]:
    """
    Converts a hexagonal Miller index to a cubic Miller index.

    Parameters
    ----------
    hex_idx : tuple[int, int, int, int]
        Hexagonal Miller index.

    Returns
    -------
    tuple[int, int, int]
        Cubic Miller index.

    Raises
    ------
    ValueError
        If the input hexagonal Miller index does not have 4 elements.
    """
    if len(hex_idx) != 4:
        raise ValueError("Hexagonal Miller index must have 4 elements.")

    return (hex_idx[0], hex_idx[1], hex_idx[3])
