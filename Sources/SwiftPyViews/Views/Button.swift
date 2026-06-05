////
////  Button.swift
////  swiftpy-views
////
////  Created by Tibor Felföldy on 2025-11-01.
////

import SwiftPy
import SwiftUI

extension PyObject {
    var asView: AnyView? {
        if let str = String(self) {
            return AnyView(erasing: SwiftUI.Text(str))
        }
        return reference.view
    }
}

/// A control that initiates an action.
@Scriptable(base: .View)
@Observable
final class Button: ViewRepresentable {
    internal var contentRevision = 0
    
    /// A view that describes the purpose of the button's action.
    var label: PyObject? {
        didSet { contentRevision += 1 }
    }

    /// The action to perform when the user triggers the button.
    var action: PyObject?

    /// Creates a button that generates its label from a string.
    init(_ title: String, action: PyObject? = nil) {
        self.label = py.retain(Text(text: title))
        self.action = action
    }
    
    /// Creates a button that displays a custom label.
    init(label: PyObject, action: PyObject? = nil) {
        self.label = label
        self.action = action
    }

    struct Content: RepresentationContent {
        @State var model: Button

        @State private var isProgressing = false

        var body: some View {
            SwiftUI.Button {
                let result = try? model.action?()

                if let task = AsyncTask(result) {
                    isProgressing = true
                    Task {
                        await task.untilCompletes()
                        isProgressing = false
                    }
                }
            } label: {
                model.label?.asView
                    .opacity(isProgressing ? 0 : 1)
                    .overlay {
                        if isProgressing {
                            ProgressView()
                        }
                    }
                    .id(model.contentRevision)
            }
            .disabled(isProgressing)
            #if !os(visionOS)
            .buttonStyle(.glass)
            #endif
            .controlSize(.extraLarge)
        }
    }
}

#Preview {
    Button("Test").representation
}
