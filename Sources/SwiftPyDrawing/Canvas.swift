//
//  Canvas.swift
//  swiftpy-views
//

import PencilKit
import SwiftPy
import SwiftPyViews
import SwiftUI

// `views.Image`, as the interface names what `image()` returns.
typealias Image = PyObject

/// A canvas to draw on with Apple Pencil or a finger. On the Mac, which has no
/// PencilKit canvas, it shows its strokes without being drawn on.
///
/// ```python
/// import drawing
///
/// def changed(strokes):
///     print(len(strokes), "strokes")
///
/// canvas = drawing.Canvas(on_change=changed)
/// ```
@Scriptable(base: .View)
@MainActor
@Observable
final class Canvas {
    /// The strokes drawn on it. Replacing them can be undone.
    var strokes: [Stroke] {
        get { drawing.strokes.map(Stroke.init) }
        set { change(to: PKDrawing(strokes: newValue.map(\.value))) }
    }

    /// What it draws with: a `Tool`, or its name.
    var tool: ToolValue {
        didSet {
            if !tool.isKnown { tool = oldValue }
            toolChanged()
        }
    }

    /// The ink's color: a `views.Color`, or `#RRGGBB` or `#RRGGBBAA`.
    var color: ColorValue {
        didSet { toolChanged() }
    }

    /// The ink's width; None is the tool's own.
    var width: Double? {
        didSet { toolChanged() }
    }

    /// Whether the system's tool picker shows while it's drawn on.
    var toolPicker: Bool

    /// Whether only Apple Pencil draws, a finger scrolling past it instead.
    var pencilOnly: Bool

    /// Called with the strokes when the user changes them. A change from code
    /// doesn't call it.
    var onChange: PyObject?

    internal private(set) var drawing = PKDrawing()
    /// Counts changes from code, for the canvas view to take them.
    internal private(set) var revision = 0
    /// Counts tool changes from code, for the canvas view and its picker.
    internal private(set) var toolRevision = 0
    @ObservationIgnored private var history: [PKDrawing] = []
    @ObservationIgnored private var isAdoptingTool = false

    private static let historyLimit = 100

    /// Creates a canvas.
    ///
    /// on_change: Called with the strokes when the user changes them.
    /// tool: What it draws with: a `Tool`, or its name.
    /// color: The ink's color: a `views.Color`, or `#RRGGBB` or `#RRGGBBAA`.
    /// width: The ink's width. Defaults to None, the tool's own.
    /// tool_picker: Whether the system's tool picker shows while it's drawn on. Defaults to True.
    /// pencil_only: Whether only Apple Pencil draws, a finger scrolling past it. Defaults to False.
    init(
        onChange: PyObject? = nil,
        tool: ToolValue = "pen",
        color: ColorValue = "black",
        width: Double? = nil,
        toolPicker: Bool = true,
        pencilOnly: Bool = false
    ) throws {
        guard tool.isKnown else { throw PythonError.ValueError("unknown tool: \(tool.name)") }
        _ = try SwiftUI.Color(pythonName: color.name)
        self.onChange = onChange
        self.tool = tool
        self.color = color
        self.width = width
        self.toolPicker = toolPicker
        self.pencilOnly = pencilOnly
    }

    /// Removes every stroke. It can be undone.
    func clear() {
        change(to: PKDrawing())
    }

    /// Takes back the last change, the user's or one from code.
    func undo() {
        guard let previous = history.popLast() else { return }
        drawing = previous
        revision += 1
    }

    /// The strokes drawn into an image, as far as they reach.
    ///
    /// scale: Pixels per point. Defaults to 2.
    /// background: A `views.Color`, or `#RRGGBB`, filling it behind the strokes. Defaults to None, transparent.
    func image(scale: Double = 2, background: ColorValue? = nil) throws -> Image {
        guard !drawing.strokes.isEmpty else {
            throw PythonError.ValueError("nothing is drawn")
        }
        let fill = try background.map { try PlatformColor(pythonName: $0.name) }
        let data = try DrawingImage.png(of: drawing, scale: CGFloat(scale), background: fill)
        guard let type = py.module("views")?.Image else {
            throw PythonError.ImportError("views.Image is not defined")
        }
        return try type(data)
    }

    func body() -> AnyView {
        AnyView(CanvasContent(model: self))
    }

    // MARK: Changes

    /// From code: the canvas view takes it, and it can be undone.
    private func change(to drawing: PKDrawing) {
        remember(self.drawing)
        self.drawing = drawing
        revision += 1
    }

    /// From the canvas view, which already shows it.
    internal func userChange(to drawing: PKDrawing) {
        remember(self.drawing)
        self.drawing = drawing
        onChange?.callback(with: strokes)
    }

    private func remember(_ drawing: PKDrawing) {
        history.append(drawing)
        if history.count > Self.historyLimit { history.removeFirst() }
    }

    private func toolChanged() {
        if !isAdoptingTool { toolRevision += 1 }
    }

    // MARK: Tools

    internal var pkTool: PKTool {
        guard let inkType = tool.inkType else { return PKEraserTool(.vector) }
        let ink = (try? PlatformColor(pythonName: color.name)) ?? .black
        return PKInkingTool(inkType, color: ink, width: width.map { CGFloat($0) } ?? inkType.defaultWidth)
    }

    /// What the tool picker chose, without sending it back to the picker.
    internal func adopt(_ tool: PKTool) {
        isAdoptingTool = true
        defer { isAdoptingTool = false }
        if let inking = tool as? PKInkingTool {
            self.tool = ToolValue(inkType: inking.inkType)
            color = ColorValue(stringLiteral: inking.color.hexString)
            width = Double(inking.width)
        } else if tool is PKEraserTool {
            self.tool = "eraser"
        }
    }
}

private struct CanvasContent: View {
    let model: Canvas

    var body: some View {
        SquareWhenUnbounded {
            #if canImport(UIKit)
            CanvasView(model: model)
            #else
            DrawingPicture(drawing: model.drawing)
            #endif
        }
        .fillsAvailableSpace()
    }
}

#if os(macOS)
/// The strokes where they were drawn, read-only, in the window's appearance.
private struct DrawingPicture: View {
    let drawing: PKDrawing
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let reach = CGRect(x: 0, y: 0, width: max(drawing.bounds.maxX, 1), height: max(drawing.bounds.maxY, 1))
        let appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        var picture = NSImage()
        appearance?.performAsCurrentDrawingAppearance {
            picture = drawing.image(from: reach, scale: displayScale)
        }
        return SwiftUI.Color.clear
            .overlay(alignment: .topLeading) {
                SwiftUI.Image(nsImage: picture)
            }
            .clipped()
    }
}
#endif

/// A drawing as PNG data, its ink as it shows in light mode.
enum DrawingImage {
    static func png(of drawing: PKDrawing, scale: CGFloat, background: PlatformColor?) throws -> Data {
        let rect = drawing.bounds
        #if canImport(UIKit)
        var strokes = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            strokes = drawing.image(from: rect, scale: scale)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        return renderer.pngData { context in
            if let background {
                background.setFill()
                context.fill(CGRect(origin: .zero, size: rect.size))
            }
            strokes.draw(at: .zero)
        }
        #else
        var strokes = NSImage()
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
            strokes = drawing.image(from: rect, scale: scale)
        }
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((rect.width * scale).rounded(.up)),
            pixelsHigh: Int((rect.height * scale).rounded(.up)),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            throw PythonError.RuntimeError("could not draw the image")
        }
        bitmap.size = rect.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        if let background {
            background.setFill()
            CGRect(origin: .zero, size: rect.size).fill()
        }
        strokes.draw(in: CGRect(origin: .zero, size: rect.size))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw PythonError.RuntimeError("could not encode the image")
        }
        return data
        #endif
    }
}
