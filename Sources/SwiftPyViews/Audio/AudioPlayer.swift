//
//  AudioPlayer.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-14.
//

import SwiftPy
import AVFoundation

@MainActor
@Scriptable
/// An object that plays audio data from a file.
public class AudioPlayer {
    internal let player: AVAudioPlayer

    /// Creates a player to play audio from a file.
    public init(path: String) throws {
        guard let url = URL(string: path) else {
            throw PythonError.RuntimeError("Invalid URL: \(path)")
        }
        player = try AVAudioPlayer.init(contentsOf: url)
    }

    /// Plays audio.
    public func play() {
        player.play()
    }
}
