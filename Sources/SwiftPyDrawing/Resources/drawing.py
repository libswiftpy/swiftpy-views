__doc__ = """A canvas to draw on with Apple Pencil or a finger, and the strokes drawn on it.

`Tool` shares its name with `agents.Tool`: prefer `import drawing` to a star import."""
__all__ = ["Canvas", "Stroke", "Tool", "ToolValue", "Point", "PointValue", "Bounds"]

from enum import StrEnum
from typing import NamedTuple
# What the canvas and its strokes are typed with.
from views import Callback, Color, ColorValue, Image
from _drawing import Canvas, Stroke

# Report the public module, not the private one they live in.
for _type in (Canvas, Stroke):
    _type.__module__ = __name__
del _type


class Tool(StrEnum):
    """What a canvas draws with. A stroke is never drawn by `ERASER`."""
    PEN = "pen"
    PENCIL = "pencil"
    MARKER = "marker"
    MONOLINE = "monoline"
    FOUNTAIN_PEN = "fountain_pen"
    WATERCOLOR = "watercolor"
    CRAYON = "crayon"
    ERASER = "eraser"


# What a canvas's or a stroke's `tool` takes: the enum, or its name.
type ToolValue = Tool | str


class Point(NamedTuple):
    """A point of a stroke: where it is, in points from the canvas's top left,
    and how it was drawn there."""
    x: float
    y: float
    time: float = 0.0
    """Seconds since the stroke began."""
    force: float = 1.0
    size: float = 4.0
    """The ink's width at this point."""
    opacity: float = 1.0
    azimuth: float = 0.0
    """The pencil's direction across the screen, in radians."""
    altitude: float = 1.5707963267948966
    """The pencil's angle from the screen, in radians: π/2 when upright."""


# What a `Stroke` is made from: `Point`s, or `(x, y)` tuples.
type PointValue = Point | tuple[float, float]

# A stroke's box: `(x, y, width, height)`.
type Bounds = tuple[float, float, float, float]
