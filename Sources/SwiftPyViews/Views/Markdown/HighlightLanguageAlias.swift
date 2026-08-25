//
//  HighlightLanguageAlias.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-08-25.
//

import HighlightSwift

public extension HighlightLanguage {
    /// The highlight.js alias for a language name, or `nil` when the name is
    /// empty or isn't one of the supported languages.
    static func alias(for name: String) -> String? {
        guard !name.isEmpty else { return nil }

        // Raw values are the camel cased case names, so a name has to be
        // matched case insensitively and common short forms spelled out.
        let rawValues = [
            "py": "python",
            "python-repl": "pythonRepl",
            "pycon": "pythonRepl",
            "js": "javaScript",
            "javascript": "javaScript",
            "ts": "typeScript",
            "typescript": "typeScript",
            "c++": "cPlusPlus",
            "cpp": "cPlusPlus",
            "c#": "cSharp",
            "cs": "cSharp",
            "objc": "objectiveC",
            "objective-c": "objectiveC",
            "sh": "shell",
            "zsh": "shell",
            "yml": "yaml",
            "tex": "latex",
        ]

        let name = name.lowercased()

        guard let language = Self(rawValue: rawValues[name] ?? name) else {
            return nil
        }

        // `HighlightLanguage.alias` is internal, so the spellings that differ
        // from the raw values are mapped here the same way HighlightSwift does.
        let aliases: [Self: String] = [
            .cPlusPlus: "cpp",
            .latex: "tex",
            .phpTemplate: "phptemp",
            .protocolBuffers: "protobuf",
            .pythonRepl: "python-repl",
            .visualBasic: "vbnet",
            .webAssembly: "webass",
        ]

        return aliases[language] ?? language.rawValue.lowercased()
    }
}
