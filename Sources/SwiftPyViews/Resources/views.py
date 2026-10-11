__doc__ = "Views to build user interfaces with."
__all__ = [
    "View", "Alignment",
    "Text", "Markdown", "Image",
    "VStack", "HStack", "ZStack", "Group", "ScrollView", "Form", "Section", "Divider",
    "Button", "TextField", "Toggle", "Slider", "Stepper", "Picker", "ProgressView",
    "CodeEditor", "MarkdownEditor",
    "Window",
]

from builtins import View
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


class Alignment:
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
