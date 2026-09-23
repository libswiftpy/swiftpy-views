//
//  CodeHighlighter.swift
//  swiftpy-views
//

import Foundation
import JavaScriptCore

/// Syntax highlighting as scope ranges, from a highlight.js build carrying only
/// the languages in `Scripts/highlight/entry.mjs`.
public actor CodeHighlighter {
    public static let shared = CodeHighlighter()

    private var highlightRanges: JSValue?

    public init() {}

    /// The scoped ranges of `code`, or none when the language isn't bundled.
    public func tokens(for code: String, language: String) -> [CodeToken] {
        guard case let .tokens(tokens) = outcome(for: code, language: language) else {
            return []
        }
        return tokens
    }

    internal enum Outcome: Equatable {
        case tokens([CodeToken])
        case unsupportedLanguage
        /// The emitter and the highlight.js build disagree; see `highlighter.js`.
        case failed(String)
    }

    internal func outcome(for code: String, language: String) -> Outcome {
        guard let function = loadHighlighter() else {
            return .failed("could not load the highlighter")
        }
        guard let result = function.call(withArguments: [code, language]),
              let json = result.toString()?.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: json)
        else {
            return .failed("the highlighter returned nothing")
        }

        if let ranges = payload.ranges { return .tokens(ranges) }
        if payload.unsupported == true { return .unsupportedLanguage }
        return .failed(payload.error ?? "unknown")
    }

    private struct Payload: Decodable {
        let ranges: [CodeToken]?
        let unsupported: Bool?
        let error: String?
    }

    private func loadHighlighter() -> JSValue? {
        if let highlightRanges { return highlightRanges }

        guard let context = JSContext() else { return nil }
        context.exceptionHandler = { _, exception in
            assertionFailure("highlighter: \(exception?.toString() ?? "unknown")")
        }

        // The build first, then the emitter that configures it.
        for resource in ["highlight.min", "highlighter"] {
            guard let path = Bundle.module.path(forResource: resource, ofType: "js"),
                  let script = try? String(contentsOfFile: path, encoding: .utf8)
            else { return nil }
            context.evaluateScript(script)
        }

        let function = context.objectForKeyedSubscript("highlightRanges")
        guard function?.isUndefined == false else { return nil }
        // Holds the context alive, which is what keeps the build parsed.
        highlightRanges = function
        return function
    }
}
