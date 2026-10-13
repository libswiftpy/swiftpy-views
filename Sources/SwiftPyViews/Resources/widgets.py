__doc__ = "Widgets to preview, as they'd look on the home screen."
__all__ = ["Widget", "WidgetSize"]

from enum import StrEnum
from _widgets import Widget

# Report the public module, not the private one it lives in.
Widget.__module__ = __name__


class WidgetSize(StrEnum):
    """The sizes a `Widget` comes in, from the smallest. Extra large is iPad only."""
    SMALL = "small"
    MEDIUM = "medium"
    LARGE = "large"
    EXTRA_LARGE = "extra_large"
