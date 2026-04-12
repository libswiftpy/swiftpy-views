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
final class Image: WrappedObject<SwiftUI.Image>, ViewRepresentable {
    var scaleToFit: Bool = true
    
    /// Initializes and returns the image object with the specified data.
    init(data: Data) throws {
        guard let image = SwiftUI.Image.from(data) else {
            throw PythonError.ValueError("Invalid image data.")
        }

        super.init(image)
    }

    internal override init(_ value: SwiftUI.Image) {
        super.init(value)
    }

    var view: some View {
        if scaleToFit {
            value
                .resizable()
                .scaledToFit()
        } else {
            value
        }
    }
    
    static func create(text: String) async throws -> Image {
        let creator = try await ImageCreator()

        for try await image in creator.images(for: [.text(text)], style: .animation, limit: 1) {
            let value = PlatformImage(cgImage: image.cgImage).swiftUI
            return Image(value)
        }

        throw PythonError.RuntimeError("Failed to create an image.")
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
