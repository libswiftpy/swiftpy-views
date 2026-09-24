//
//  CompletionsView.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2026. 06. 24..
//

import SwiftUI

public struct CompletionsView: View {
    let completions: [String]
    let completion: (String) -> Void

    public init(completions: [String], completion: @escaping (String) -> Void) {
        self.completions = completions
        self.completion = completion
    }

    // Falls back to a tab suggestion when there are no completions.
    private var suggestions: [String] {
        completions.isEmpty ? ["\t"] : completions
    }

    public var body: some View {
        SwiftUI.ScrollView(.horizontal, showsIndicators: false) {
            SwiftUI.HStack {
                ForEach(suggestions, id: \.self) { suggestion in
                    SwiftUI.Button {
                        completion(suggestion)
                    } label: {
                        SwiftUI.Text(suggestion, format: .completion)
                    }
                }
            }
            .padding(8)
            .glassButtonStyle()
            .buttonBorderShape(.capsule)
        }
        .monospaced()
        .mask {
            SwiftUI.HStack(spacing: 0) {
                Color.black
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
            }
        }
    }
}

#Preview {
    CompletionsView(
        completions: ["print(", "range(", "clear()", "len(", "input(", "vars()"]
    ) { _ in }
}
