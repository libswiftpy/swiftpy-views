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

@Scriptable
final class Image: ViewRepresentable {
    private let image: SwiftUI.Image
    
    init(data: Data) throws {
        guard let image = SwiftUI.Image.from(data) else {
            throw PythonError.ValueError("Invalid image data.")
        }

        self.image = image
    }
    
    var view: some View {
        image
    }
}
