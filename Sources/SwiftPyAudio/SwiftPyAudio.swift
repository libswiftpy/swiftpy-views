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

    /// The notebook running code now, which a sound made now belongs to; the host sets it.
    public static var currentOwner: @MainActor () -> String? = { nil }

    /// Stops every sound that's playing, or only an owner's, as when its notebook stops or closes.
    public static func stopAll(owner: String? = nil) {
        AudioPlayer.stopAll(owner: owner)
    }

    public static func isPlaying(owner: String) -> Bool {
        AudioPlayer.isPlaying(owner: owner)
    }
}
