//
//  SceneRenderer.swift
//  swiftpy-views
//

import CoreGraphics
import Foundation
import Metal
import RealityKit

/// Draws a scene into an image without a view, for snapshots where a window
/// can't capture a RealityView: on macOS it comes out blank.
@MainActor
enum SceneRenderer {
    static func image(of model: SceneView, size: CGSize, scale: CGFloat) async -> CGImage? {
        let width = Int(size.width * scale), height = Int(size.height * scale)
        guard width > 0, height > 0, let device = MTLCreateSystemDefaultDevice() else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor),
              let renderer = try? RealityRenderer(),
              let output = try? RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        else { return nil }

        // A copy: an entity has one parent, and the live view keeps the root.
        // Without the heartbeat, the script's systems don't run on it.
        let content = model.root.clone(recursive: true)
        for child in content.children where child.components.has(SceneHeartbeatComponent.self) {
            child.removeFromParent()
        }
        renderer.entities.append(content)
        // As the live view lights it.
        let light = DirectionalLight()
        light.light.intensity = 3000
        light.look(at: .zero, from: [1, 2, 2], relativeTo: nil)
        renderer.entities.append(light)
        renderer.activeCamera = camera(in: content) ?? framingCamera(for: content, in: renderer)
        renderer.cameraSettings.colorBackground = .color(CGColor(gray: 0, alpha: 0))

        let rendered: Bool = await withCheckedContinuation { done in
            do {
                try renderer.updateAndRender(deltaTime: 0, cameraOutput: output, onComplete: { _ in
                    done.resume(returning: true)
                })
            } catch {
                done.resume(returning: false)
            }
        }
        return rendered ? cgImage(from: texture) : nil
    }

    private static func camera(in entity: Entity) -> Entity? {
        if entity.components.has(PerspectiveCameraComponent.self) { return entity }
        return entity.children.lazy.compactMap(camera(in:)).first
    }

    /// Looking at the content from the front, as the orbit camera starts.
    private static func framingCamera(for content: Entity, in renderer: RealityRenderer) -> Entity {
        let camera = PerspectiveCamera()
        let bounds = content.visualBounds(relativeTo: nil)
        let radius = max(bounds.boundingRadius, 0.05)
        let halfFOV = camera.camera.fieldOfViewInDegrees / 2 * .pi / 180
        let distance = radius / sin(halfFOV) * 1.1
        camera.look(at: bounds.center, from: bounds.center + [0, 0, distance], relativeTo: nil)
        renderer.entities.append(camera)
        return camera
    }

    private static func cgImage(from texture: MTLTexture) -> CGImage? {
        let bytesPerRow = texture.width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * texture.height)
        texture.getBytes(&bytes, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(
            width: texture.width, height: texture.height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: bytesPerRow, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }
}
