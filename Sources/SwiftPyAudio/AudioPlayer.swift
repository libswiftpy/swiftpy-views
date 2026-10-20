//
//  AudioPlayer.swift
//  swiftpy-views
//

import AVFoundation
import SwiftPy

/// Plays a sound file, or encoded audio bytes.
@Scriptable
@MainActor
final class AudioPlayer {
    private let player: AVAudioPlayer
    private let delegate = Delegate()
    private var waiters: [CheckedContinuation<Void, any Error>] = []
    // Between play() and the audio session becoming active.
    private var isStarting = false

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
        Self.playing[ObjectIdentifier(self)] = self
        #if os(iOS) || os(visionOS)
        Self.activateSession { [weak self] in self?.start() }
        #else
        start()
        #endif
    }

    private func start() {
        guard isStarting else { return }
        isStarting = false
        if !player.play() {
            finish(throwing: Self.error("playback couldn't start"))
        }
    }

    #if os(iOS) || os(visionOS)
    private static let sessionQueue = DispatchQueue(label: "swiftpy-audio.session")

    // Activating blocks, so it's done off the main thread.
    private static func activateSession(then start: @escaping @MainActor () -> Void) {
        sessionQueue.async {
            let session = AVAudioSession.sharedInstance()
            // Plays with the silent switch on, as media does.
            try? session.setCategory(.playback)
            try? session.setActive(true)
            Task { @MainActor in start() }
        }
    }
    #endif

    /// Pauses, keeping the position.
    func pause() {
        isStarting = false
        player.pause()
        Self.playing[ObjectIdentifier(self)] = nil
    }

    /// Stops playback and resets the position to zero.
    func stop() {
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
