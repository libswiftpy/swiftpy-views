//
//  AudioPlayer.swift
//  swiftpy-views
//

// AVAudioPlayer is Sendable on iOS, but not yet on macOS.
@preconcurrency import AVFoundation
import SwiftPy

/// Plays a sound file, or encoded audio bytes.
@Scriptable
@MainActor
final class AudioPlayer {
    private nonisolated let player: AVAudioPlayer
    private let delegate = Delegate()
    private var waiters: [CheckedContinuation<Void, any Error>] = []
    // Between play() and the player starting, off the main thread.
    private var isStarting = false
    private var isStoppedWhileStarting = false

    // Playing players keep themselves alive, so a sound nothing refers to plays on.
    internal private(set) static var playing: [ObjectIdentifier: AudioPlayer] = [:]

    /// Loads a local file or encoded audio bytes. Relative paths use the notebook's working directory. Doesn't start playback.
    ///
    /// source: A path, as a str or a `PathLike`, or the bytes of an encoded file such as MP3, M4A or WAV.
    /// volume: From 0.0 to 1.0. Defaults to 1.0.
    /// loop: Whether it repeats until stopped. Defaults to False.
    init(source: AudioSource, volume: Double = 1.0, loop: Bool = false) throws {
        do {
            switch source {
            case .data(let data):
                player = try AVAudioPlayer(data: data)
            case .file(let url):
                guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
                    throw Self.error("no such file: \(url.path(percentEncoded: false))")
                }
                player = try AVAudioPlayer(contentsOf: url)
            }
        } catch let error as PythonError {
            throw error
        } catch {
            throw Self.error("couldn't load the audio: \(error.localizedDescription)")
        }
        // Rate only takes effect when enabled before playback is prepared.
        // play() prepares: preparing here would activate the session on the main thread.
        player.enableRate = true
        player.delegate = delegate
        self.volume = volume
        self.loop = loop
        delegate.owner = self
    }

    /// From 0.0 to 1.0.
    var volume: Double {
        get { Double(player.volume) }
        set { player.volume = Float(min(max(newValue, 0), 1)) }
    }

    /// The playback speed, from 0.5 to 2.0, where 1.0 is normal.
    var rate: Double {
        get { Double(player.rate) }
        set { player.rate = Float(min(max(newValue, 0.5), 2)) }
    }

    /// Whether it repeats until stopped.
    var loop: Bool {
        get { player.numberOfLoops < 0 }
        set { player.numberOfLoops = newValue ? -1 : 0 }
    }

    /// The playback position in seconds.
    var position: Double {
        get { player.currentTime }
        set { player.currentTime = min(max(newValue, 0), player.duration) }
    }

    /// The total duration in seconds.
    var duration: Double {
        player.duration
    }

    /// Whether it's playing now.
    var isPlaying: Bool {
        isStarting || player.isPlaying
    }

    /// Starts or resumes playback, and returns at once.
    func play() {
        guard !isPlaying else { return }
        isStarting = true
        isStoppedWhileStarting = false
        Self.playing[ObjectIdentifier(self)] = self
        Task {
            started(await start())
        }
    }

    // Setting the category and `play()`, which activates the session, block.
    @concurrent
    private nonisolated func start() async -> Bool {
        #if os(iOS) || os(visionOS)
        // Plays with the silent switch on, as media does, unless the app
        // chose a category that isn't muted by it.
        let session = AVAudioSession.sharedInstance()
        if session.category == .soloAmbient || session.category == .ambient {
            try? session.setCategory(.playback)
        }
        #endif
        return player.play()
    }

    private func started(_ didStart: Bool) {
        guard isStarting else {
            // Paused or stopped while it started.
            player.pause()
            if isStoppedWhileStarting { player.currentTime = 0 }
            return
        }
        isStarting = false
        if !didStart {
            finish(throwing: Self.error("playback couldn't start"))
        }
    }

    /// Pauses, keeping the position.
    func pause() {
        isStarting = false
        player.pause()
        Self.playing[ObjectIdentifier(self)] = nil
    }

    /// Stops playback and resets the position to zero.
    func stop() {
        isStoppedWhileStarting = isStarting
        isStarting = false
        player.stop()
        player.currentTime = 0
        finish(throwing: nil)
    }

    /// Waits for the playback to finish or be stopped. Raises `AudioError` if playback fails.
    func wait() async throws {
        guard isPlaying else { return }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(continuation)
            }
        } onCancel: {
            // Stopping the run stops what it waits for.
            Task { @MainActor in self.stop() }
        }
    }

    /// Stops every player that's playing.
    internal static func stopAll() {
        for player in playing.values {
            player.stop()
        }
    }

    private func finish(throwing error: (any Error)?) {
        Self.playing[ObjectIdentifier(self)] = nil
        let pending = waiters
        waiters = []
        for waiter in pending {
            if let error {
                waiter.resume(throwing: error)
            } else {
                waiter.resume()
            }
        }
    }

    private static func error(_ message: String) -> PythonError {
        PythonError(type: "audio.AudioError", value: message)
    }

    // AVAudioPlayer's delegate must be an NSObject.
    private final class Delegate: NSObject, AVAudioPlayerDelegate {
        weak var owner: AudioPlayer?

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            Task { @MainActor in
                self.owner?.finish(throwing: flag ? nil : AudioPlayer.error("playback failed"))
            }
        }

        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
            let message = error?.localizedDescription ?? "the audio couldn't be decoded"
            Task { @MainActor in
                self.owner?.finish(throwing: AudioPlayer.error("playback failed: \(message)"))
            }
        }
    }
}
