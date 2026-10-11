__doc__ = "Views to build user interfaces with."
__all__ = [
    "View", "Alignment", "Font", "Edges", "Axis", "PickerStyle", "ButtonRole", "ControlSize", "Color",
    "Text", "Markdown", "Image",
    "VStack", "HStack", "ZStack", "Group", "ScrollView", "Form", "Section", "Divider",
    "Button", "TextField", "Toggle", "Slider", "Stepper", "Picker", "ProgressView",
    "CodeEditor", "MarkdownEditor",
    "Window",
]

from builtins import View
from enum import StrEnum
from _views import (
    Button, CodeEditor, Divider, Form, Group, HStack, Image, Markdown,
    MarkdownEditor, ModifiedView, Picker, ProgressView, ScrollView, Section,
    Slider, Stepper, Text, TextField, Toggle, VStack, Window, ZStack,
)

# Report the public module, not the private one they live in.
for _type in (
    Button, CodeEditor, Divider, Form, Group, HStack, Image, Markdown,
    MarkdownEditor, ModifiedView, Picker, ProgressView, ScrollView, Section,
    Slider, Stepper, Text, TextField, Toggle, VStack, Window, ZStack,
):
    _type.__module__ = __name__
del _type


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
    INLINE = "inline"


class ButtonRole(StrEnum):
    """What a `Button` is styled for."""
    DESTRUCTIVE = "destructive"
    CANCEL = "cancel"


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
