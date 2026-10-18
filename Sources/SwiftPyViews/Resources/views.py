__doc__ = "Views to build user interfaces with."
__all__ = [
    "View", "Alignment", "Font", "Edges", "Axis", "PickerStyle", "ButtonRole", "ButtonStyle", "ControlSize", "Color",
    "Text", "Markdown", "Image",
    "VStack", "HStack", "ZStack", "Group", "ScrollView", "Form", "Section", "Divider", "Rectangle",
    "SizeContainer", "Sizing", "Transform", "Length", "LengthExpression", "Percent", "AlignmentValue",
    "Button", "TextField", "Toggle", "Slider", "Stepper", "Picker", "Progress",
    "CodeEditor", "MarkdownEditor",
    "Pan", "Vector2",
    "Window", "animate",
]

from builtins import View
from enum import StrEnum
from typing import NamedTuple
from _views import (
    Button, CodeEditor, Divider, Form, Group, HStack, Image, Markdown,
    MarkdownEditor, ModifiedView, Pan, Picker, Progress, Rectangle, ScrollView, Section,
    SizeContainer, Sizing, Slider, Stepper, Text, TextField, Toggle, Transform, VStack, Window,
    ZStack, animate,
)

# Report the public module, not the private one they live in.
for _type in (
    Button, CodeEditor, Divider, Form, Group, HStack, Image, Markdown,
    MarkdownEditor, ModifiedView, Pan, Picker, Progress, Rectangle, ScrollView, Section,
    SizeContainer, Sizing, Slider, Stepper, Text, TextField, Toggle, Transform, VStack, Window,
    ZStack,
):
    _type.__module__ = __name__
del _type
animate.__module__ = __name__


class Alignment(StrEnum):
    """Where views sit in a stack, or in the space `View.align` gives them."""
    CENTER = "center"
    LEADING = "leading"
    TRAILING = "trailing"
    TOP = "top"
    BOTTOM = "bottom"
    TOP_LEADING = "top-leading"
    TOP_TRAILING = "top-trailing"
    BOTTOM_LEADING = "bottom-leading"
    BOTTOM_TRAILING = "bottom-trailing"



# What a container's `alignment` takes: the enum, or its name.
type AlignmentValue = Alignment | str


class Font(StrEnum):
    """Text styles for `View.font`, from the largest."""
    LARGE_TITLE = "large_title"
    TITLE = "title"
    TITLE2 = "title2"
    TITLE3 = "title3"
    HEADLINE = "headline"
    SUBHEADLINE = "subheadline"
    BODY = "body"
    CALLOUT = "callout"
    FOOTNOTE = "footnote"
    CAPTION = "caption"
    CAPTION2 = "caption2"


class Edges(StrEnum):
    """The edges `View.padding` pads."""
    ALL = "all"
    HORIZONTAL = "horizontal"
    VERTICAL = "vertical"
    TOP = "top"
    BOTTOM = "bottom"
    LEADING = "leading"
    TRAILING = "trailing"


class Axis(StrEnum):
    """The direction a `ScrollView` scrolls."""
    VERTICAL = "vertical"
    HORIZONTAL = "horizontal"


class PickerStyle(StrEnum):
    """How a `Picker` shows its options."""
    MENU = "menu"
    SEGMENTED = "segmented"


class ButtonRole(StrEnum):
    """What a `Button` is styled for."""
    DESTRUCTIVE = "destructive"
    CANCEL = "cancel"


class ButtonStyle(StrEnum):
    """How `View.button_style` draws the buttons inside."""
    GLASS = "glass"
    PLAIN = "plain"


class ControlSize(StrEnum):
    """How big `View.control_size` makes the controls inside, from the smallest."""
    MINI = "mini"
    SMALL = "small"
    REGULAR = "regular"
    LARGE = "large"
    EXTRA_LARGE = "extra_large"


class Color(StrEnum):
    """Colors by name. A hex string, "#RRGGBB" or "#RRGGBBAA", works too."""
    RED = "red"
    ORANGE = "orange"
    YELLOW = "yellow"
    GREEN = "green"
    MINT = "mint"
    TEAL = "teal"
    CYAN = "cyan"
    BLUE = "blue"
    INDIGO = "indigo"
    PURPLE = "purple"
    PINK = "pink"
    BROWN = "brown"
    GRAY = "gray"
    BLACK = "black"
    WHITE = "white"
    CLEAR = "clear"
    PRIMARY = "primary"
    SECONDARY = "secondary"
    ACCENT = "accent"


class LengthExpression:
    """A length that layout works out: a percentage of the nearest
    `SizeContainer`, of its width for a width or `x` and of its height for a
    height or `y`, plus points. Make one from `Percent`, adding or subtracting
    points."""

    __slots__ = ("percent", "points")

    def __init__(self, percent: float = 0, points: float = 0) -> None:
        self.percent = float(percent)
        self.points = float(points)

    def __add__(self, points: float) -> LengthExpression:
        if isinstance(points, LengthExpression) or not isinstance(points, (int, float)):
            return NotImplemented
        return LengthExpression(self.percent, self.points + points)

    __radd__ = __add__

    def __sub__(self, points: float) -> LengthExpression:
        if isinstance(points, LengthExpression) or not isinstance(points, (int, float)):
            return NotImplemented
        return LengthExpression(self.percent, self.points - points)

    def __rsub__(self, points: float) -> LengthExpression:
        if not isinstance(points, (int, float)):
            return NotImplemented
        return LengthExpression(-self.percent, points - self.points)

    def __eq__(self, other):
        if not isinstance(other, LengthExpression):
            return NotImplemented
        return (self.percent, self.points) == (other.percent, other.points)

    def __hash__(self):
        return hash((self.percent, self.points))

    def __repr__(self) -> str:
        text = f"Percent({self.percent:g})"
        if self.points > 0:
            return f"{text} + {self.points:g}"
        if self.points < 0:
            return f"{text} - {-self.points:g}"
        return text


class Percent(LengthExpression):
    """A percentage of the nearest `SizeContainer`: of its width for a width
    or `x`, of its height for a height or `y`. Add or subtract points, as in
    `Percent(50) - 10`."""

    __slots__ = ()

    def __init__(self, value: float) -> None:
        super().__init__(value, 0)


type Length = float | LengthExpression

# What a type checker and `help` read: `_class_lines` leaves out dunders.
LengthExpression._interface = '''class LengthExpression:
    """A length that layout works out: a percentage of the nearest
    `SizeContainer`, plus points. Make one from `Percent`, adding or
    subtracting points.

    Attributes:
        percent: The percentage of the container's width or height.
        points: Points added to it.
    """
    percent: float
    points: float

    def __init__(self, percent: float = 0, points: float = 0) -> None: ...
    def __add__(self, points: float) -> LengthExpression: ...
    def __radd__(self, points: float) -> LengthExpression: ...
    def __sub__(self, points: float) -> LengthExpression: ...
    def __rsub__(self, points: float) -> LengthExpression: ...'''

Percent._interface = '''class Percent(LengthExpression):
    """A percentage of the nearest `SizeContainer`: of its width for a width
    or `x`, of its height for a height or `y`. Add or subtract points, as in
    `Percent(50) - 10`.
    """

    def __init__(self, value: float) -> None: ...'''


class Vector2(NamedTuple):
    """An `x` and a `y`, such as how far a `Pan` was dragged: in points, to
    the right and down."""
    x: float
    y: float
