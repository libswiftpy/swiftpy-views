//
//  CodeToken.swift
//  swiftpy-views
//

import Foundation

/// A scoped range of source, in UTF-16 units.
public struct CodeToken: Sendable, Equatable, Decodable {
    public let range: NSRange
    public let scope: CodeScope

    public init(range: NSRange, scope: CodeScope) {
        self.range = range
        self.scope = scope
    }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let location = try container.decode(Int.self)
        let length = try container.decode(Int.self)
        range = NSRange(location: location, length: length)
        scope = CodeScope(try container.decode(String.self))
    }
}

/// A highlight.js scope, as far as the palette distinguishes them.
public enum CodeScope: String, Sendable, Hashable, CaseIterable {
    case plain
    case keyword, literal, type, builtIn = "built_in", params
    case string, subst, comment, quote, number
    case title, titleClass = "title.class"
    case meta, section, variable, templateVariable = "template-variable"
    case attr, attribute, tag, name, selectorTag = "selector-tag"
    case symbol, bullet, regexp, link, doctag, code, property
    case `operator`, punctuation
    case addition, deletion

    /// Maps a scope name to a case, narrowing a dotted scope one component at a
    /// time so an unknown variant lands on its family rather than on `plain`.
    public init(_ name: String) {
        var name = name

        while !name.isEmpty {
            if let scope = CodeScope(rawValue: name) {
                self = scope
                return
            }
            guard let dot = name.lastIndex(of: ".") else { break }
            name = String(name[name.startIndex..<dot])
        }

        self = .plain
    }
}
