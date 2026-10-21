//
//  AudioPlayerTests.swift
//  swiftpy-views
//

import Foundation
import Testing
import SwiftPy
@testable import SwiftPyAudio

@MainActor
@Suite(.serialized)
struct AudioPlayerTests {
    init() async throws {
        SwiftPyAudio.initialize()
        py.main._silence = try Self.silence(seconds: 0.3).toPython()
        await Interpreter.run("""
        from audio import *

        def _raised(f):
            try:
                f()
            except Exception as e:
                return type(e).__name__
            return None
        """)
    }

    /// A mono 16-bit PCM WAV of silence.
    static func silence(seconds: Double) -> Data {
        let rate = 8000
        let samples = Int(Double(rate) * seconds)
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + samples * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(rate))
        append(UInt32(rate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(samples * 2))
        data.append(Data(count: samples * 2))
        return data
    }

    private func evaluate<T: PythonConvertible>(_ expression: String) -> T? {
        Interpreter.evaluate(expression)
    }

    @Test func loadsBytesWithDefaults() async throws {
        await Interpreter.run("_player = AudioPlayer(_silence)")
        let duration: Double = try #require(evaluate("_player.duration"))
        #expect(abs(duration - 0.3) < 0.01)
        #expect(evaluate("repr([_player.volume, _player.rate, _player.loop, _player.position, _player.is_playing, _player.mix])")
            == "[1.0, 1.0, False, 0.0, False, False]")
    }

    @Test func propertiesReadBackWhatWasSet() async throws {
        await Interpreter.run("""
        _player = AudioPlayer(_silence, volume=0.5, loop=True, mix=True)
        _given = [_player.volume, _player.loop, _player.mix]
        _player.volume = 3
        _player.rate = 1.5
        _player.loop = False
        _player.mix = False
        _player.position = 0.1
        """)
        #expect(evaluate("repr(_given)") == "[0.5, True, True]")
        #expect(evaluate("repr([_player.volume, _player.rate, _player.loop, _player.mix])") == "[1.0, 1.5, False, False]")
        let position: Double = try #require(evaluate("_player.position"))
        #expect(abs(position - 0.1) < 0.01)
    }

    @Test func playsPausesAndStops() async {
        await Interpreter.run("""
        _player = AudioPlayer(_silence, loop=True)
        _player.play()
        _playing = _player.is_playing
        _player.position = 0.2
        _player.pause()
        _paused = (_player.is_playing, round(_player.position, 1))
        _player.play()
        _player.stop()
        _stopped = (_player.is_playing, _player.position)
        """)
        #expect(evaluate("_playing") == true)
        #expect(evaluate("repr(_paused)") == "(False, 0.2)")
        #expect(evaluate("repr(_stopped)") == "(False, 0.0)")
    }

    @Test func waitsUntilTheClipEnds() async throws {
        await Interpreter.run("""
        import time
        _player = AudioPlayer(_silence)
        _player.play()
        _start = time.monotonic()
        await _player.wait()
        _waited = time.monotonic() - _start
        _after = _player.is_playing
        await _player.wait()
        """)
        let waited: Double = try #require(evaluate("_waited"))
        #expect(waited > 0.2)
        #expect(evaluate("_after") == false)
    }

    @Test func waitsForALoopUntilItsStopped() async {
        await Interpreter.run("""
        import asyncio
        _player = AudioPlayer(_silence, loop=True)
        _player.play()
        asyncio.get_running_loop().call_later(0.5, _player.stop)
        await _player.wait()
        _after = (_player.is_playing, _player.position)
        """)
        #expect(evaluate("repr(_after)") == "(False, 0.0)")
    }

    @Test func loadsPathsAgainstTheCurrentDirectory() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Self.silence(seconds: 0.3).write(to: folder.appending(path: "clip.wav"))
        let previous = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(previous) }

        py.main._folder = try folder.path(percentEncoded: false).toPython()
        await Interpreter.run("""
        import os, pathlib
        os.chdir(_folder)
        _durations = [round(AudioPlayer(source).duration, 1) for source in ("clip.wav", pathlib.Path("clip.wav"))]
        """)
        #expect(evaluate("repr(_durations)") == "[0.3, 0.3]")
    }

    @Test func raisesForWhatItCantLoad() async {
        await Interpreter.run("""
        _missing = _raised(lambda: AudioPlayer("no-such-file.wav"))
        _garbage = _raised(lambda: AudioPlayer(b"not audio"))
        _number = _raised(lambda: AudioPlayer(42))
        _is_exception = issubclass(AudioError, Exception)
        """)
        #expect(evaluate("_missing") == "AudioError")
        #expect(evaluate("_garbage") == "AudioError")
        #expect(evaluate("_number") == "TypeError")
        #expect(evaluate("_is_exception") == true)
    }

    @Test func aPlayerNothingRefersToPlaysUntilStopped() async {
        await Interpreter.run("""
        import gc
        AudioPlayer(_silence, loop=True).play()
        gc.collect()
        """)
        #expect(!AudioPlayer.playing.isEmpty)
        SwiftPyAudio.stopAll()
        #expect(AudioPlayer.playing.isEmpty)
    }
}
