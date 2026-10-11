//
//  StyleNames.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

// The strings Python names colors, fonts and edges with.

extension Color {
    init(pythonName name: String) throws {
        if name.hasPrefix("#") {
            self = try Self.hex(name)
            return
        }
        switch name {
        case "red": self = .red
        case "orange": self = .orange
        case "yellow": self = .yellow
        case "green": self = .green
        case "mint": self = .mint
        case "teal": self = .teal
        case "cyan": self = .cyan
        case "blue": self = .blue
        case "indigo": self = .indigo
        case "purple": self = .purple
        case "pink": self = .pink
        case "brown": self = .brown
        case "gray": self = .gray
        case "black": self = .black
        case "white": self = .white
        case "clear": self = .clear
        case "primary": self = .primary
        case "secondary": self = .secondary
        case "accent": self = .accentColor
        default: throw PythonError(type: "ValueError", value: "unknown color: \(name)")
        }
    }

    /// "#RRGGBB" or "#RRGGBBAA".
    private static func hex(_ text: String) throws -> Color {
        let digits = text.dropFirst()
        guard digits.count == 6 || digits.count == 8,
              let value = UInt64(digits, radix: 16) else {
            throw PythonError(type: "ValueError", value: "a hex color is #RRGGBB or #RRGGBBAA, not \(text)")
        }
        let rgba = digits.count == 6 ? value << 8 | 0xFF : value
        func channel(_ shift: UInt64) -> Double { Double(rgba >> shift & 0xFF) / 255 }
        return Color(.sRGB, red: channel(24), green: channel(16), blue: channel(8), opacity: channel(0))
    }
}

extension Font {
    init(pythonName name: String) throws {
        switch name {
        case "large_title": self = .largeTitle
        case "title": self = .title
        case "title2": self = .title2
        case "title3": self = .title3
        case "headline": self = .headline
        case "subheadline": self = .subheadline
        case "body": self = .body
        case "callout": self = .callout
        case "footnote": self = .footnote
        case "caption": self = .caption
        case "caption2": self = .caption2
        default: throw PythonError(type: "ValueError", value: "unknown font: \(name)")
        }
    }
}

extension Edge.Set {
    init(pythonName name: String) throws {
        switch name {
        case "all": self = .all
        case "horizontal": self = .horizontal
        case "vertical": self = .vertical
        case "top": self = .top
        case "bottom": self = .bottom
        case "leading": self = .leading
        case "trailing": self = .trailing
        default: throw PythonError(type: "ValueError", value: "unknown edges: \(name)")
        }
    }
}

extension ControlSize {
    init(pythonName name: String) throws {
        switch name {
        case "mini": self = .mini
        case "small": self = .small
        case "regular": self = .regular
        case "large": self = .large
        case "extra_large": self = .extraLarge
        default: throw PythonError(type: "ValueError", value: "unknown control size: \(name)")
        }
    }
}
