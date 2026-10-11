//
//  Alignment.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-12-18.
//

import SwiftUI

// The names `views.Alignment` gives, as SwiftUI's alignments.
enum Alignment {
    internal static func horizontal(_ alignment: String) -> HorizontalAlignment? {
        switch alignment {
        case "left", "leading", "top-leading", "bottom-leading": .leading
        case "right", "trailing", "top-trailing", "bottom-trailing": .trailing
        default: nil
        }
    }
    
    internal static func vertical(_ alignment: String) -> VerticalAlignment? {
        switch alignment {
        case "top", "top-leading", "top-trailing": .top
        case "bottom", "bottom-leading", "bottom-trailing": .bottom
        default: nil
        }
    }

    internal static func both(_ alignment: String) -> SwiftUI.Alignment {
        SwiftUI.Alignment(
            horizontal: horizontal(alignment) ?? .center,
            vertical: vertical(alignment) ?? .center
        )
    }
}
