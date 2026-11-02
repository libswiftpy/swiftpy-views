__doc__ = "Plays sound files and encoded audio bytes."
__all__ = ["AudioPlayer", "AudioError", "AudioSource"]

from os import PathLike
from _audio import AudioPlayer


# A path to a file, or the bytes of an encoded one.
type AudioSource = str | PathLike[str] | bytes


class AudioError(Exception):
    """An audio loading or playback failure."""
