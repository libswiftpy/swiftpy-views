//
//  Music.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-25.
//

import MusicKit
import SwiftPy

@MainActor
@Scriptable
final class Music {
    /// Asks the user for permission to access MusicKit.
    static func authorize() async throws {
        switch MusicAuthorization.currentStatus {
        case .denied, .restricted:
            throw PythonError.RuntimeError("You need to authorize the app to access Music library.")
        case .authorized:
            break
        case .notDetermined:
            _ = await MusicAuthorization.request()
            try await authorize()
        @unknown default:
            break
        }
    }
}

/// An object the app uses to play music.
@Scriptable
final class MusicPlayer: WrappedObject<ApplicationMusicPlayer.Queue> {
    /// Creates a player with a queue of songs.
    init(songs: [Song]) {
        let queue = ApplicationMusicPlayer.Queue(for: songs.map(\.value))
        super.init(queue)
    }

    /// Initiates playback from the current queue.
    func play() async throws {
        ApplicationMusicPlayer.shared.queue = value
        try await ApplicationMusicPlayer.shared.prepareToPlay()
        try await ApplicationMusicPlayer.shared.play()
    }

    /// Pauses playback.
    func pause() {
        ApplicationMusicPlayer.shared.pause()
    }
}

/// A music item that represents a song.
@Scriptable
@MainActor
final class Song: WrappedObject<MusicKit.Song>, Sendable {
    @Attribute(\.id.rawValue)
    var id: String
    
    /// The title of the song.
    @Attribute(\.title)
    var title: String

    /// The artist’s name.
    @Attribute(\.artistName)
    var artistName: String

    /// Fetch songs from the Apple Music catalog using a search term.
    static func search(term: String) async throws -> [Song] {
        try await Music.authorize()
        let request = MusicCatalogSearchRequest(term: term, types: [MusicKit.Song.self])
        let response = try await request.response()
        return response.songs.map(Song.init)
    }

    /// Fetches a song by the specified id.
    static func fromId(id: String) async throws -> Song? {
        try await Music.authorize()
        let result = try await MusicCatalogResourceRequest<MusicKit.Song>(
            matching: \SongFilter.id,
            equalTo: MusicItemID(id)
        )
        .response()

        return result.items.map(Song.init).first
    }
}
