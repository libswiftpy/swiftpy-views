//
//  FillsAvailableSpace.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-09-22.
//

import SwiftUI

/// Set by a view that fills the space it is given, so its container knows to
/// hand over that space rather than nest it in a scroll view.
public struct FillsAvailableSpaceKey: PreferenceKey {
    public static let defaultValue = false

    public static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

public extension View {
    func fillsAvailableSpace() -> some View {
        preference(key: FillsAvailableSpaceKey.self, value: true)
    }
}
