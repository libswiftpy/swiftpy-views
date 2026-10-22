//
//  CanvasView.swift
//  swiftpy-views
//

#if canImport(UIKit)
import PencilKit
import SwiftUI

/// PencilKit's canvas, kept in step with the model: the user's strokes go to
/// it, and its changes from code come here.
struct CanvasView: UIViewRepresentable {
    let model: Canvas

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.delegate = context.coordinator
        context.coordinator.toolPicker.addObserver(view)
        context.coordinator.toolPicker.addObserver(context.coordinator)
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        view.drawingPolicy = model.pencilOnly ? .pencilOnly : .anyInput

        if coordinator.revision != model.revision {
            coordinator.revision = model.revision
            coordinator.isApplying = true
            view.drawing = model.drawing
            coordinator.isApplying = false
        }
        if coordinator.toolRevision != model.toolRevision {
            coordinator.toolRevision = model.toolRevision
            view.tool = model.pkTool
            coordinator.toolPicker.selectedTool = model.pkTool
        }
        coordinator.toolPicker.setVisible(model.toolPicker, forFirstResponder: view)
    }

    static func dismantleUIView(_ view: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker.setVisible(false, forFirstResponder: view)
        coordinator.toolPicker.removeObserver(view)
        coordinator.toolPicker.removeObserver(coordinator)
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate, PKToolPickerObserver {
        var model: Canvas
        let toolPicker = PKToolPicker()
        var revision = -1
        var toolRevision = -1
        /// Set while a drawing from code is put in, which isn't the user's.
        var isApplying = false

        init(model: Canvas) {
            self.model = model
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplying else { return }
            model.userChange(to: canvasView.drawing)
        }

        // Only once it's drawn on: becoming first responder on its own would
        // take the keyboard from a card being edited.
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            if model.toolPicker, !canvasView.isFirstResponder {
                canvasView.becomeFirstResponder()
            }
        }

        func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
            model.adopt(toolPicker.selectedTool)
        }
    }
}
#endif
