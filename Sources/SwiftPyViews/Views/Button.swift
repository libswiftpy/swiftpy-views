//
//  Button.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-01.
//

import SwiftPy
import SwiftUI

@Scriptable(base: .View)
@Observable
final class Button: ViewRepresentable, Container {
    internal var updateCount = 0
    
    var label: object? {
        get { self[.content] }
        set {
            self[.content] = [newValue]
            updateCount += 1
        }
    }

    var action: object? {
        get { self[.action] }
        set {
            self[.action] = newValue
            updateCount += 1
        }
    }

    init(arguments: PyArguments) {
        if arguments.count > 1 {
            if let text = String(arguments[1]) {
                let textObj = Text(text: text).retained
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
                model.contentView
                    .opacity(isProgressing ? 0 : 1)
                    .overlay {
                        if isProgressing {
                            ProgressView()
                        }
                    }
                    .id(model.updateCount)
            }
            .disabled(isProgressing)
            #if !os(visionOS)
            .buttonStyle(.glass)
            #endif
            .controlSize(.extraLarge)
        }
    }
}
