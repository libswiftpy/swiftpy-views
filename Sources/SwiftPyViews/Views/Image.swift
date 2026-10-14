//
//  Image.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-03.
//

import SwiftUI
import SwiftPy
import ImagePlayground

/// A view that displays an image.
@Scriptable(base: .View)
final class Image: WrappedObject<SwiftUI.Image> {
    var scaleToFit: Bool = true

    // What `png()` encodes; a system symbol has none.
    internal var pixels: PlatformImage?

    /// Initializes and returns the image object with the specified data.
    init(data: Data) throws {
        guard let pixels = PlatformImage(data: data) else {
            throw PythonError.ValueError("Invalid image data.")
        }

        super.init(pixels.swiftUI)
        self.pixels = pixels
    }

    internal override init(_ value: SwiftUI.Image) {
        super.init(value)
    }

    func body() -> AnyView {
        if scaleToFit {
            AnyView(value.resizable().scaledToFit())
        } else {
            AnyView(value)
        }
    }
    
    static func create(text: String) async throws -> Image {
        let creator = try await ImageCreator()

        for try await image in creator.images(for: [.text(text)], style: .animation, limit: 1) {
            return Image(pixels: PlatformImage(cgImage: image.cgImage))
        }

        throw PythonError.RuntimeError("Failed to create an image.")
    }

    /// Draws a view into an image, as it shows in the app, in light or dark mode.
    ///
    /// view: The view to draw, or a string drawn as text.
    /// width: Its width in points. Defaults to the window's; the height fits the content.
    /// delay: Seconds to wait before drawing, for content that loads, like an image from the web.
    /// background: A `Color`, or "#RRGGBB", filling the image behind the view. Defaults to None, the app's own background in light or dark mode; `Color.CLEAR` leaves it transparent.
    static func render(view: PyObject, width: Double? = nil, delay: Double = 0, background: String? = nil) async throws -> Image {
        guard let content = view.asView else {
            throw PythonError.TypeError("can't render \(view.typeName), not a view")
        }
        let fill = try background.map(Color.init(pythonName:))
        let pixels = await ViewSnapshot.image(of: content, width: width.map { CGFloat($0) }, delay: delay, background: fill)
        return Image(pixels: pixels)
    }

    /// The image as PNG data.
    func png() throws -> Data {
        guard let data = pixels?.png else {
            throw PythonError.ValueError("this image has no pixels of its own, like a system symbol")
        }
        return data
    }

    private convenience init(pixels: PlatformImage) {
        self.init(pixels.swiftUI)
        self.pixels = pixels
    }

    /// Creates a system symbol image.
    static func system(name: String) -> Image {
        let image = Image(SwiftUI.Image(systemName: name))
        image.scaleToFit = false
        return image
    }
}

#if canImport(UIKit)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage

extension PlatformImage {
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
#endif

extension PlatformImage {
    var swiftUI: SwiftUI.Image {
        #if canImport(UIKit)
        return SwiftUI.Image(uiImage: self)
        #else
        return SwiftUI.Image(nsImage: self)
        #endif
    }
}

extension SwiftUI.Image {
    static func from(_ data: Data) -> SwiftUI.Image? {
        PlatformImage(data: data)?.swiftUI
    }
}
