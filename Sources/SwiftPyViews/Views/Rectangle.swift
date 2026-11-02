//
//  Rectangle.swift
//  swiftpy-views
//

import SwiftPy
import SwiftUI

/// A filled rectangle, such as behind a view with `background`.
@Scriptable(base: .View)
@MainActor
@Observable
final class Rectangle {
    /// The fill: a `Color`, or a hex string such as `#RRGGBB`; None for the foreground color.
    var color: ColorValue?
    /// The corners' radius, or None to follow the corners around it.
    var cornerRadius: Double?

    /// Creates a rectangle.
    ///
    /// color: The fill: a `Color`, such as `Color.TEAL`, or "#RRGGBB". Defaults to None, the foreground color.
    /// corner_radius: The corners' radius: 0 for square ones. Defaults to None, which rounds them to follow the corners around it, such as a card's.
    init(color: ColorValue? = nil, cornerRadius: Double? = nil) throws {
        if let color { _ = try SwiftUI.Color(pythonName: color.name) }
        self.color = color
        self.cornerRadius = cornerRadius
    }

    func body() -> AnyView {
        AnyView(RectangleContent(model: self))
    }
}

private struct RectangleContent: View {
    let model: Rectangle

    var body: some View {
        if let fill = model.color.flatMap({ try? SwiftUI.Color(pythonName: $0.name) }) {
            shape.fill(fill)
        } else {
            shape
        }
    }

    private var shape: AnyShape {
        switch model.cornerRadius {
        case nil: AnyShape(ConcentricRectangle.followingCorners)
        case 0: AnyShape(SwiftUI.Rectangle())
        case let radius?: AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

extension ConcentricRectangle {
    // Far from the corners it follows, a concentric one would turn square.
    static var followingCorners: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(8)), isUniform: true)
    }
}
