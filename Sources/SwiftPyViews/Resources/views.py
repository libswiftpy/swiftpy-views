__doc__ = "Views to build user interfaces with."
__all__ = ["CodeEditor", "Markdown", "MarkdownEditor", "Window"]

from _views import CodeEditor, Markdown, MarkdownEditor, Window

# Report the public module, not the private one they live in.
for _type in (CodeEditor, Markdown, MarkdownEditor, Window):
    _type.__module__ = __name__
del _type
