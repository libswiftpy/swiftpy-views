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
            coordinator.selectInPicker(model.pkTool)
            // After the picker, which sets its own item's tool on the canvas.
            view.tool = model.pkTool
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
        /// Set while a tool from code is selected in the picker.
        private var isSelecting = false

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

        func toolPickerSelectedToolItemDidChange(_ toolPicker: PKToolPicker) {
            guard !isSelecting else { return }
            let item = toolPicker.selectedToolItem
            if let inking = item as? PKToolPickerInkingItem {
                model.adopt(inking.inkingTool)
            } else if let eraser = item as? PKToolPickerEraserItem {
                model.adopt(eraser.eraserTool)
            }
        }

        /// The picker's item of the same kind: an item's color and width
        /// can't be changed, so those stay the canvas's own.
        func selectInPicker(_ tool: PKTool) {
            let item = toolPicker.toolItems.first { item in
                if let inking = tool as? PKInkingTool {
                    return (item as? PKToolPickerInkingItem)?.inkingTool.inkType == inking.inkType
                }
                return tool is PKEraserTool && item is PKToolPickerEraserItem
            }
            guard let item else { return }
            isSelecting = true
            toolPicker.selectedToolItemIdentifier = item.identifier
            isSelecting = false
        }
    }
}
#endif
