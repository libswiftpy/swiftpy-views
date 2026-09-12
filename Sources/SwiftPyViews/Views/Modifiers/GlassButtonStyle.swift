//
//  GlassButtonStyle.swift
//  swiftpy-views
//

import SwiftUI

public extension View {
    /// `.glass` where it exists; visionOS draws its own glass on `.bordered`.
    func glassButtonStyle() -> some View {
        #if os(visionOS)
        buttonStyle(.bordered)
        #else
        buttonStyle(.glass)
        #endif
    }
}
