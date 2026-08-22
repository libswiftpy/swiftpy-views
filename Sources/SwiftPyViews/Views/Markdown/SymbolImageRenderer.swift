//
//  SymbolImageRenderer.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026-08-22.
//

import SwiftUI
import MarkdownView

@MainActor
struct SymbolImageRenderer: MarkdownImageRenderer {
    func makeBody(configuration: MarkdownImageRendererConfiguration) -> some View {
        let name = configuration.url.host ?? configuration.url.lastPathComponent

        SwiftUI.Image(systemName: name)
            .accessibilityLabel(configuration.alternativeText ?? name)
    }
}
