//
//  Model3D.swift
//  swiftpy-views
//
//  Created by Tibor Felföldy on 2025-11-29.
//

import SwiftPy
import SwiftUI
import RealityKit
import LogTools

@Scriptable(base: .View)
final class Model3D: ViewRepresentable {
    typealias Path = SwiftPy.Path
    
    let path: Path
    
    init(path: Path) {
        self.path = path
    }
    
    init(name: String) throws {
        self.path = try Path(path: name)
    }
    
    struct Content: RepresentationContent {
        @State var model: Model3D
        
        @State private var height: CGFloat?
        
        var body: some View {
            #if os(visionOS)
            RealityKit.Model3D(url: model.path.url)
            #else
            RealityView { content in
                do {
                    let url = URL(fileURLWithPath: model.path.url.path)
                    let entity = try await Entity(contentsOf: url)
                    content.add(entity)
                    content.cameraTarget = entity
                } catch {
                    Logger().critical(error.localizedDescription)
                }
            }
            .realityViewCameraControls(.orbit)
            .realityViewLayoutBehavior(.centered)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { newValue in
                self.height = newValue
            }
            .frame(minHeight: height)
            #endif
        }
    }
}

