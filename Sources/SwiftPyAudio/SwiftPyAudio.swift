//
//  SwiftPyAudio.swift
//  swiftpy-views
//

import SwiftPy

@MainActor
public enum SwiftPyAudio {
    public static func initialize() {
        // Native, then re-exported by `audio` beside what's written in Python.
        PyBind.module("_audio", docs: "Native audio.") { module in
            module.classes(AudioPlayer.self)
        }
        PyBind.module("audio", in: .module)
    }

    /// Stops every sound that's playing, as when the notebook stops or changes.
    public static func stopAll() {
        AudioPlayer.stopAll()
    }
}
