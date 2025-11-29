//
//  Image.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-03.
//

import SwiftUI
import SwiftPy

extension SwiftUI.Image {
    static func from(_ data: Data) -> SwiftUI.Image? {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return SwiftUI.Image(uiImage: uiImage)
        #else
        guard let nsImage = NSImage(data: data) else { return nil }
        return SwiftUI.Image(nsImage: nsImage)
        #endif
    }
}

/// A view that displays an image.
@Scriptable(base: .View)
final class Image: WrappedObject<SwiftUI.Image>, ViewRepresentable {
    /// Initializes and returns the image object with the specified data.
    init(data: Data) throws {
        guard let image = SwiftUI.Image.from(data) else {
            throw PythonError.ValueError("Invalid image data.")
        }

        super.init(image)
    }
    
    var view: some View {
        value
    }
}
