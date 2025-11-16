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
public class AudioPlayer {
    internal let player: AVAudioPlayer

    public init(path: String) throws {
        guard let url = URL(string: path) else {
            throw PythonError.RuntimeError("Invalid URL: \(path)")
        }
        player = try AVAudioPlayer(contentsOf: url)
    }

    public func play() {
        player.play()
    }
}
