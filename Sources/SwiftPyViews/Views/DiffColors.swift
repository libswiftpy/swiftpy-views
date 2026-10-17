//
//  DiffColors.swift
//  swiftpy-views
//

import SwiftUI
import SyntaxHighlight

extension Color {
    /// An added line's tint. Stronger in light mode, where a faint tint washes
    /// out on white.
    static let diffAdded = adaptive(base: .systemGreen, light: 0.3, dark: 0.25)
    /// A removed line's tint.
    static let diffRemoved = adaptive(base: .systemRed, light: 0.22, dark: 0.25)

    private static func adaptive(base: CodeColor, light: CGFloat, dark: CGFloat) -> Color {
        #if os(macOS)
        Color(platformColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return base.withAlphaComponent(isDark ? dark : light)
        })
        #else
        Color(platformColor: UIColor { traits in
            base.withAlphaComponent(traits.userInterfaceStyle == .dark ? dark : light)
        })
        #endif
    }
}
