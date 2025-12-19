//
//  Alignment.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-12-18.
//

import SwiftPy
import SwiftUI

@Scriptable(convertsToSnakeCase: false)
final class Alignment {
    static let CENTER = "center"
    static let LEADING = "leading"
    static let TRAILING = "trailing"
    static let TOP = "top"
    static let BOTTOM = "bottom"
    static let TOP_LEADING = "top-leading"
    static let TOP_TRAILING = "top-trailing"
    static let BOTTOM_LEADING = "bottom-leading"
    static let BOTTOM_TRAILING = "bottom-trailing"
    
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
}
