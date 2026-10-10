__doc__ = "Views to build user interfaces with."
__all__ = ["CodeEditor", "Markdown", "MarkdownEditor", "Slider", "Window"]

from _views import CodeEditor, Markdown, MarkdownEditor, Slider, Window

# Report the public module, not the private one they live in.
for _type in (CodeEditor, Markdown, MarkdownEditor, Slider, Window):
    _type.__module__ = __name__
del _type
