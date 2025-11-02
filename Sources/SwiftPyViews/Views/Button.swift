//
//  Button.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-01.
//

import SwiftPy
import SwiftUI

@Observable
@Scriptable(base: .View)
final class Button: ViewRepresentable, Container {
    init(arguments: PyArguments) {
        if arguments.count > 1 {
            if let text = String(arguments[1]) {
                let textObj = Text(text: text).toStack
                arguments[Slot.content] = textObj.reference
            } else {
                arguments[Slot.content] = arguments[1]
            }
        }

        if arguments.count > 2 {
            arguments[Slot.action] = arguments[2]
        }
    }

    struct Content: RepresentationContent {
        @State var model: Button

        @State private var isProgressing = false

        var body: some View {
            SwiftUI.Button {
                let result = try? model[.action]?.call()

                if let task = AsyncTask(result) {
                    isProgressing = true
                    Task {
                        await task.untilCompletes()
                        isProgressing = false
                    }
                }
            } label: {
                model[.content]?.view?.view
                    .opacity(isProgressing ? 0 : 1)
                    .overlay {
                        if isProgressing {
                            ProgressView()
                        }
                    }
            }
            .disabled(isProgressing)
            .buttonStyle(.glass)
            .controlSize(.extraLarge)
        }
    }
}
