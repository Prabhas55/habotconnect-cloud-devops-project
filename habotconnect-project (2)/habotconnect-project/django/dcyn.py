"""
DCYN (Deconstructed Clean Yes/No) validation library.

Purpose: eliminate ambiguous or human-judged boolean interpretation
from onboarding data. Any incoming value that is not one of the
explicitly whitelisted representations of Yes or No is rejected
outright — there is no "best guess" fallback, by design (Poka-Yoke).
"""

from typing import Any


class DCYNError(ValueError):
    """Raised when a value cannot be deterministically mapped to Yes/No."""


_YES_VALUES = frozenset({"yes", "y", "true", "1"})
_NO_VALUES = frozenset({"no", "n", "false", "0"})


def to_dcyn(value: Any) -> bool:
    """
    Deterministically map a raw input value to a strict boolean.

    Accepts only exact, case-insensitive matches from a fixed whitelist.
    Anything else (empty string, null, "maybe", "N/A", "pending", etc.)
    raises DCYNError. The caller must not silently coerce ambiguous input
    into a guessed True/False.
    """
    if isinstance(value, bool):
        return value

    if value is None:
        raise DCYNError("DCYN field cannot be null — explicit Yes/No is required.")

    normalized = str(value).strip().lower()

    if normalized in _YES_VALUES:
        return True
    if normalized in _NO_VALUES:
        return False

    raise DCYNError(
        f"'{value}' is not a valid DCYN value. "
        f"Allowed values: {sorted(_YES_VALUES | _NO_VALUES)}"
    )
