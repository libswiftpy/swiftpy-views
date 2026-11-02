//
//  Pan.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A view that a finger drags across, for a loop such as a game's to read how
/// far it moved each frame. Dragging in it doesn't scroll the notebook.
///
/// ```python
/// from views import *
///
/// pan = Pan(Rectangle(Color.TEAL).size(height=200))
/// delta = pan.consume_delta()  # Vector2(x=0.0, y=0.0) until it's dragged
/// ```
@Scriptable(base: .View)
@MainActor
@Observable
final class Pan {
    /// The view, or a string to show as text.
    var content: PyObject

    /// Whether a finger is dragging across it.
    var isPanning: Bool { panning }

    internal var panning = false
    /// Moved since it was last consumed; read when asked, not drawn.
    @ObservationIgnored internal var pending = CGSize.zero

    /// Creates a pan.
    ///
    /// content: A view, or a string to show as text.
    init(content: PyObject) {
        self.content = content
    }

    /// How far it was dragged since the last call, in points, and starts
    /// counting again: a `Vector2`, `x` to the right and `y` down.
    func consumeDelta() throws -> PyObject {
        let delta = pending
        pending = .zero
        guard let type = py.module("views")?.Vector2 else {
            throw PythonError.ImportError("views.Vector2 is not defined")
        }
        return try type(Double(delta.width), Double(delta.height))
    }

    func body() -> AnyView {
        AnyView(PanContent(model: self))
    }
}

private struct PanContent: View {
    let model: Pan
    /// The drag's translation when it was last added to the model.
    @State private var counted = CGSize.zero
    /// Ends with the drag however it ends, cancelled by the system too.
    @GestureState private var isDragging = false

    var body: some View {
        (model.content.asView ?? AnyView(EmptyView()))
            .contentShape(.rect)
            // Over the notebook's scrolling, inside it.
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { add($0.translation) }
                    .onEnded { add($0.translation) }
            )
            .onChange(of: isDragging) { _, isDragging in
                model.panning = isDragging
                if !isDragging { counted = .zero }
            }
            .onDisappear { model.panning = false }
    }

    private func add(_ translation: CGSize) {
        model.pending.width += translation.width - counted.width
        model.pending.height += translation.height - counted.height
        counted = translation
    }
}
