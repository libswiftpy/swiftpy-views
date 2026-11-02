//
//  AudioSource.swift
//  swiftpy-views
//

import Foundation
import SwiftPy

/// `audio.AudioSource`: encoded audio bytes, or a path to a file.
enum AudioSource {
    case data(Data)
    case file(URL)
}

@MainActor
extension AudioSource: PythonConvertible {
    // Only named in the TypeError a wrong argument raises.
    static var pyType: PyType { .str }

    static func isConvertible(_ reference: PyRef) -> Bool {
        Data.isConvertible(reference)
            || String.isConvertible(reference)
            || PyObject(retaining: reference).__fspath__ != nil
    }

    static func fromPython(_ reference: PyRef) -> AudioSource {
        if Data.isConvertible(reference) {
            return .data(Data.fromPython(reference))
        }
        let path: String = (try? py.module("os")?.fspath?(PyObject(retaining: reference))) ?? ""
        // Relative to the current directory, which the notebook sets.
        return .file(URL(fileURLWithPath: path))
    }

    func toPython() throws(PythonError) -> PyObject {
        switch self {
        case .data(let data): try data.toPython()
        case .file(let url): try url.path(percentEncoded: false).toPython()
        }
    }
}
