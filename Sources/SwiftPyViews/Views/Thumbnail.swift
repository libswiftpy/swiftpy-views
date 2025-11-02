//
//  Thumbnail.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-01.
//

import QuickLookThumbnailing
import SwiftPy
import SwiftUI

@Scriptable(base: .View)
final class Thumbnail: ViewRepresentable {
    internal let url: URL
    
    init(path: String) throws {
        guard let url = URL(string: path) else {
            throw PythonError.ValueError("Invalid path: \(path)")
        }
        self.url = url
    }
    
    var view: some View {
        ThumbnailView(url: url)
    }
}

struct ThumbnailView: View {
    let url: URL
    @Environment(\.displayScale) var scale
    
    @State var image: Image?
    
    var body: some View {
        Group {
            if let image {
                image.resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(width: 64, height: 64)
        .task {
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: 64, height: 64),
                scale: scale,
                representationTypes: .icon
            )
            
            let representation = try? await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request)
            if let representation {
                #if canImport(UIKit)
                self.image = Image(uiImage: representation.uiImage)
                #else
                self.image = Image(nsImage: representation.nsImage)
                #endif
            }
        }
    }
}
