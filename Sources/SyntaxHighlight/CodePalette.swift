//
//  CodePalette.swift
//  swiftpy-views
//

import SwiftUI

#if canImport(UIKit)
import UIKit
public typealias CodeColor = UIColor
#else
import AppKit
public typealias CodeColor = NSColor
#endif

/// The one style the highlighter ships, transcribed from Xcode's theme.
public struct CodePalette: Sendable {
    public static let xcode = CodePalette()

    public func color(for scope: CodeScope, in colorScheme: ColorScheme) -> CodeColor {
        let palette = colorScheme == .dark ? Self.dark : Self.light

        guard let hex = palette[scope] else {
            #if canImport(UIKit)
            return .label
            #else
            return .labelColor
            #endif
        }
        return CodeColor(hex: hex)
    }

    // Scopes left out take the default text colour, as they do in Xcode.
    // `addition` and `deletion` are ours: the theme has no diff colours.
    private static let light: [CodeScope: UInt32] = [
        .comment: 0x007400, .quote: 0x007400, .doctag: 0x007400,
        .keyword: 0xAA0D91, .literal: 0xAA0D91, .name: 0xAA0D91,
        .selectorTag: 0xAA0D91, .tag: 0xAA0D91, .attribute: 0xAA0D91,
        .variable: 0x3F6E74, .templateVariable: 0x3F6E74,
        .string: 0xC41A16, .code: 0xC41A16,
        .link: 0x0E0EFF, .regexp: 0x0E0EFF,
        .bullet: 0x1C00CF, .number: 0x1C00CF, .symbol: 0x1C00CF, .title: 0x1C00CF,
        .meta: 0x643820, .section: 0x643820,
        .builtIn: 0x5C2699, .titleClass: 0x5C2699, .params: 0x5C2699, .type: 0x5C2699,
        .attr: 0x836C28,
        .addition: 0x007400, .deletion: 0xC41A16,
    ]

    private static let dark: [CodeScope: UInt32] = [
        .comment: 0x6C7986, .quote: 0x6C7986, .doctag: 0x6C7986,
        .keyword: 0xFC5FA3, .literal: 0xFC5FA3, .name: 0xFC5FA3,
        .selectorTag: 0xFC5FA3, .tag: 0xFC5FA3, .attribute: 0xFC5FA3,
        .variable: 0xFC5FA3, .templateVariable: 0xFC5FA3,
        .meta: 0xFC5FA3, .section: 0xFC5FA3,
        .string: 0xFC6A5D, .code: 0xFC6A5D,
        .link: 0x5482FF, .regexp: 0x5482FF,
        .bullet: 0x41A1C0, .number: 0x41A1C0, .symbol: 0x41A1C0, .title: 0x41A1C0,
        .builtIn: 0xD0A8FF, .titleClass: 0xD0A8FF, .params: 0xD0A8FF, .type: 0xD0A8FF,
        .attr: 0xBF8555,
        .addition: 0x67C090, .deletion: 0xFC6A5D,
    ]
}

private extension CodeColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
