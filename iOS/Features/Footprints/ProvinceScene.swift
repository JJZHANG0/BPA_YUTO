import SceneKit
import SwiftUI

struct ProvinceCameraCommand {
    enum Action { case zoomIn, zoomOut, reset }
    let id = UUID()
    let action: Action
}

struct ProvinceScene: UIViewRepresentable {
    let visited: Set<String>
    let selected: String?
    let cameraCommand: ProvinceCameraCommand?
    let onSelect: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase

    func makeUIView(context: Context) -> ProvinceDiorama {
        ProvinceDiorama(frame: .zero)
    }

    func updateUIView(_ view: ProvinceDiorama, context: Context) {
        view.onSelect = onSelect
        view.setMotionAllowed(!reduceMotion && phase == .active)
        view.display(visited: visited, selected: selected)
        if let command = cameraCommand { view.perform(command) }
    }

    static func dismantleUIView(_ view: ProvinceDiorama, coordinator: ()) {
        view.setMotionAllowed(false)
    }
}

private struct ProvinceOutline: Decodable {
    let name: String
    let interactive: Bool
    let anchor: [CGFloat]
    let rings: [[[CGFloat]]]

    static let map: [ProvinceOutline] = {
        guard let url = Bundle.main.url(forResource: "ProvinceMap", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let outlines = try? JSONDecoder().decode([Self].self, from: data) else { return [] }
        return outlines
    }()
}

private extension UIColor {
    convenience init(mapRGB value: Int) {
        self.init(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                  blue: CGFloat(value & 255) / 255, alpha: 1)
    }
}

final class ProvinceDiorama: SCNView, UIGestureRecognizerDelegate {
    var onSelect: (String) -> Void = { _ in }
    private let cameraNode = SCNNode()
    private let land = SCNNode()
    private let stage = SCNScene()
    private struct Tile {
        let body: SCNNode
        let cap: SCNMaterial
        let sides: SCNMaterial
        let rim: SCNMaterial
        let base: UIColor
        let edge: UIColor
        let label: SCNNode
    }
    private static let relief = UIImage(named: "ProvinceRelief").flatMap(rgbaTexture)

    // Asset catalogs may decode our single-channel terrain as a grayscale CGImage.
    // Use the RGBA8/sRGB layout supported by both device and simulator Metal renderers.
    private static func rgbaTexture(_ image: UIImage) -> CGImage? {
        guard let source = image.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: source.width, height: source.height,
                                      bitsPerComponent: 8, bytesPerRow: source.width * 4,
                                      space: space,
                                      bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        return context.makeImage()
    }

    private var tiles: [String: Tile] = [:]
    private let defaultLabelNames = Set(["新疆", "西藏", "四川", "北京", "黑龙江"])
    private var lastVisited = Set<String>()
    private var lastSelected: String?
    private var handledCommand: UUID?
    private var motionAllowed = false
    private var yaw: Float = -0.04
    private var elevation: Float = 0.94
    private var zoom = 1.0
    private var offset = SIMD2<Float>(0, 0)
    private var animatedNodes: [(SCNNode, SCNAction)] = []

    override init(frame: CGRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        scene = stage
        isOpaque = false
        backgroundColor = .clear
        stage.background.contents = UIColor.clear
        antialiasingMode = .multisampling4X
        preferredFramesPerSecond = 30
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityIdentifier = "province-scene"
        accessibilityLabel = "可交互的立体省份地图"
        accessibilityHint = "也可以使用省份列表选择目的地"
        stage.rootNode.addChildNode(land)
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.zNear = 0.1
        camera.zFar = 75
        cameraNode.camera = camera
        stage.rootNode.addChildNode(cameraNode)
        pointOfView = cameraNode
        buildLighting()
        for (index, outline) in ProvinceOutline.map.enumerated() { buildTile(outline, index: index) }
        installGestures()
        updateCamera()
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCamera()
    }

    private func buildLighting() {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(mapRGB: 0xFFF4DF)
        ambient.intensity = 530
        let room = SCNNode()
        room.light = ambient
        stage.rootNode.addChildNode(room)
        let key = SCNLight()
        key.type = .directional
        key.color = UIColor(mapRGB: 0xFFF2D9)
        key.intensity = 840
        key.castsShadow = true
        key.shadowColor = UIColor(white: 0.15, alpha: 0.26)
        key.shadowSampleCount = 12
        key.shadowRadius = 4
        key.shadowMapSize = CGSize(width: 1024, height: 1024)
        key.orthographicScale = 11
        key.zNear = 1
        key.zFar = 38
        let sun = SCNNode()
        sun.light = key
        sun.position = SCNVector3(-6, 14, 5)
        sun.look(at: SCNVector3Zero)
        stage.rootNode.addChildNode(sun)
        let fill = SCNLight()
        fill.type = .directional
        fill.color = UIColor(mapRGB: 0xDCECEB)
        fill.intensity = 250
        let bounce = SCNNode()
        bounce.light = fill
        bounce.position = SCNVector3(4, 5, -4)
        bounce.look(at: SCNVector3Zero)
        stage.rootNode.addChildNode(bounce)

        // A translucent contact-shadow decal blends onto the SwiftUI paper background.
        let width: CGFloat = 13.5, height: CGFloat = 12.0, resolution: CGFloat = 48
        let area = CGSize(width: width * resolution, height: height * resolution)
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .standard
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: area, format: format).image { renderer in
            let cg = renderer.cgContext
            cg.setShadow(offset: CGSize(width: 3, height: 4), blur: 8,
                         color: UIColor(mapRGB: 0x3D4934).withAlphaComponent(0.55).cgColor)
            cg.setFillColor(UIColor(mapRGB: 0x586249).cgColor)
            for item in ProvinceOutline.map {
                for ring in item.rings {
                    for (i, point) in ring.enumerated() {
                        let location = CGPoint(x: (width / 2 + point[0]) * resolution,
                                               y: (height / 2 - point[1]) * resolution)
                        if i == 0 { cg.move(to: location) } else { cg.addLine(to: location) }
                    }
                    cg.closePath()
                }
            }
            cg.drawPath(using: .eoFill)
        }
        let plane = SCNPlane(width: width, height: height)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = Self.rgbaTexture(image)
        mat.transparency = 0.34
        mat.writesToDepthBuffer = false
        plane.materials = [mat]
        let ground = SCNNode(geometry: plane)
        ground.eulerAngles.x = -.pi / 2
        ground.position.y = -0.29
        ground.castsShadow = false
        ground.renderingOrder = -10
        stage.rootNode.addChildNode(ground)
    }

    private func buildTile(_ outline: ProvinceOutline, index: Int) {
        let anchor = CGPoint(x: outline.anchor[0], y: outline.anchor[1])
        let path = UIBezierPath()
        path.usesEvenOddFillRule = true
        for ring in outline.rings where ring.count >= 3 {
            for (index, point) in ring.enumerated() {
                let p = CGPoint(x: point[0] - anchor.x, y: point[1] - anchor.y)
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.close()
        }
        let palette = [0x8BA99B, 0xA2B9A7, 0x85A495, 0xA4B8A5, 0x95AE9B, 0x8DAA9B, 0xB0BFA7]
        let base = UIColor(mapRGB: outline.interactive ? palette[index % palette.count] : 0xB7C4B5)
        let edge = UIColor(mapRGB: 0x647E70)
        let cap = Self.material(base)
        let side = Self.material(edge)
        let rim = Self.material(UIColor(mapRGB: 0xD3D8B8))
        let shape = SCNShape(path: path, extrusionDepth: 0.34)
        shape.chamferRadius = 0.012
        // Derive texture coordinates from projected world positions so the actual
        // mountain ranges align across provincial borders and the offshore islands.
        shape.shaderModifiers = [.geometry: """
            #pragma arguments
            float3 reliefAnchor;
            #pragma body
            _geometry.texcoords[0] = float2((_geometry.position.x + reliefAnchor.x + 6.1) / 12.2,
                                            (5.5 - _geometry.position.y - reliefAnchor.y) / 11.0);
            """]
        shape.setValue(NSValue(scnVector3: SCNVector3(Float(anchor.x), Float(anchor.y), 0)), forKey: "reliefAnchor")
        cap.multiply.contents = Self.relief
        cap.multiply.intensity = 0.80
        shape.materials = [cap, cap, side, rim]
        let slab = SCNNode(geometry: shape)
        slab.eulerAngles.x = -.pi / 2
        // A hairline gap lets adjacent pieces read independently, including at rest.
        slab.scale = SCNVector3(0.989, 0.989, 1)
        let group = SCNNode()
        group.position = SCNVector3(Float(anchor.x), 0, -Float(anchor.y))
        group.addChildNode(slab)
        land.addChildNode(group)
        guard outline.interactive else { return }
        group.name = outline.name
        let landmark = miniaturize(outline.name)
        if let landmark {
            landmark.position.y = 0.18
            landmark.scale = SCNVector3(1.26, 1.26, 1.26)
            group.addChildNode(landmark)
        }
        let label = Self.nameplate(outline.name)
        let tallLandmark = outline.name == "北京" || outline.name == "浙江"
        label.position = SCNVector3(0, landmark == nil ? 0.42 : tallLandmark ? 1.46 : 1.02, landmark == nil ? 0 : -0.48)
        label.isHidden = !defaultLabelNames.contains(outline.name)
        group.addChildNode(label)
        tiles[outline.name] = Tile(body: group, cap: cap, sides: side, rim: rim, base: base, edge: edge, label: label)
    }

    private static func material(_ color: UIColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .blinn
        mat.diffuse.contents = color
        mat.specular.contents = UIColor(white: 0.24, alpha: 1)
        mat.shininess = 0.24
        return mat
    }

    private static func nameplate(_ name: String) -> SCNNode {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 26, weight: .semibold),
                                                        .foregroundColor: UIColor.white]
        let text = name as NSString
        let size = text.size(withAttributes: attributes)
        let bounds = CGRect(x: 0, y: 0, width: ceil(size.width) + 20, height: 40)
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .standard
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { _ in
            UIColor(mapRGB: 0x244B40).setFill()
            UIBezierPath(roundedRect: bounds, cornerRadius: 12).fill()
            text.draw(at: CGPoint(x: 10, y: (40 - size.height) / 2), withAttributes: attributes)
        }
        let plane = SCNPlane(width: bounds.width / 72, height: bounds.height / 72)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = Self.rgbaTexture(image)
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        node.castsShadow = false
        return node
    }

    func display(visited: Set<String>, selected: String?) {
        guard visited != lastVisited || selected != lastSelected else { return }
        let changed = visited.symmetricDifference(lastVisited).union([selected, lastSelected].compactMap { $0 })
        SCNTransaction.begin()
        SCNTransaction.animationDuration = motionAllowed ? 0.3 : 0
        for name in changed {
            guard let tile = tiles[name] else { continue }
            let lit = visited.contains(name)
            let focused = name == selected
            tile.body.position.y = lit ? 0.26 : focused ? 0.11 : 0
            tile.cap.diffuse.contents = lit ? UIColor(mapRGB: 0xE9B659) : focused ? UIColor(mapRGB: 0x78A998) : tile.base
            tile.sides.diffuse.contents = lit ? UIColor(mapRGB: 0xB8802F) : tile.edge
            tile.rim.emission.contents = lit ? UIColor(mapRGB: 0xC38129) : UIColor.black
            tile.rim.diffuse.contents = lit ? UIColor(mapRGB: 0xFFDF8C) : UIColor(mapRGB: 0xD3D8B8)
            tile.label.isHidden = !focused && !defaultLabelNames.contains(name)
        }
        SCNTransaction.commit()
        lastVisited = visited
        lastSelected = selected
        accessibilityValue = "已点亮\(visited.count)个省份"
        setNeedsDisplay()
    }

    func setMotionAllowed(_ allowed: Bool) {
        guard allowed != motionAllowed else { return }
        motionAllowed = allowed
        for (node, action) in animatedNodes {
            node.removeAction(forKey: "life")
            node.eulerAngles = SCNVector3Zero
            if allowed { node.runAction(action, forKey: "life") }
        }
        isPlaying = allowed
    }

    func perform(_ command: ProvinceCameraCommand) {
        guard handledCommand != command.id else { return }
        handledCommand = command.id
        switch command.action {
        case .zoomIn:
            if let lastSelected, let tile = tiles[lastSelected] {
                offset = SIMD2(tile.body.position.x, tile.body.position.z)
            }
            zoom = min(4.5, zoom * 1.35)
        case .zoomOut: zoom = max(0.85, zoom / 1.35)
        case .reset: zoom = 1; yaw = -0.04; elevation = 0.94; offset = .zero
        }
        updateCamera()
    }

    private func updateCamera() {
        guard bounds.height > 0, bounds.width > 0 else { return }
        let aspect = Double(bounds.width / bounds.height)
        let halfHeight = max(5.0, 6.6 / aspect)
        cameraNode.camera?.orthographicScale = halfHeight / zoom
        let target = SCNVector3(offset.x, 0.12, offset.y)
        cameraNode.position = SCNVector3(offset.x + 20 * sin(yaw) * cos(elevation),
                                         0.12 + 20 * sin(elevation),
                                         offset.y + 20 * cos(yaw) * cos(elevation))
        cameraNode.look(at: target)
        setNeedsDisplay()
    }

    private func installGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
        let orbit = UIPanGestureRecognizer(target: self, action: #selector(rotated))
        orbit.maximumNumberOfTouches = 1
        addGestureRecognizer(orbit)
        let move = UIPanGestureRecognizer(target: self, action: #selector(panned))
        move.minimumNumberOfTouches = 2
        move.maximumNumberOfTouches = 2
        move.delegate = self
        addGestureRecognizer(move)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched))
        pinch.delegate = self
        addGestureRecognizer(pinch)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer.view === self) ||
        (otherGestureRecognizer is UIPinchGestureRecognizer && gestureRecognizer.view === self)
    }

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
        for hit in hitTest(tap.location(in: self), options: [.searchMode: SCNHitTestSearchMode.all.rawValue]) {
            var cursor: SCNNode? = hit.node
            while let current = cursor {
                if let name = current.name, tiles[name] != nil { onSelect(name); return }
                cursor = current.parent
            }
        }
    }

    @objc private func rotated(_ gesture: UIPanGestureRecognizer) {
        let delta = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        yaw -= Float(delta.x) * 0.007
        elevation = min(1.46, max(0.58, elevation + Float(delta.y) * 0.005))
        updateCamera()
    }

    @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
        zoom = max(0.85, min(4.5, zoom * Double(gesture.scale)))
        gesture.scale = 1
        updateCamera()
    }

    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        guard bounds.height > 0 else { return }
        let delta = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        let units = Float(2 * (cameraNode.camera?.orthographicScale ?? 1) / Double(bounds.height))
        let x = -Float(delta.x) * units
        let z = -Float(delta.y) * units / sin(elevation)
        offset.x = min(6, max(-6, offset.x + x * cos(yaw) + z * sin(yaw)))
        offset.y = min(5, max(-5, offset.y - x * sin(yaw) + z * cos(yaw)))
        updateCamera()
    }
}

private extension ProvinceDiorama {
    @discardableResult
    func attach(_ geometry: SCNGeometry, color: Int, at position: SCNVector3, to parent: SCNNode) -> SCNNode {
        geometry.materials = [Self.material(UIColor(mapRGB: color))]
        let node = SCNNode(geometry: geometry)
        node.position = position
        parent.addChildNode(node)
        return node
    }

    @discardableResult
    func pebble(_ radius: CGFloat, _ color: Int, _ x: Float, _ y: Float, _ z: Float,
                _ scale: SCNVector3, in parent: SCNNode) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        sphere.segmentCount = 16
        let node = attach(sphere, color: color, at: SCNVector3(x, y, z), to: parent)
        node.scale = scale
        return node
    }

    func cylinder(_ radius: CGFloat, height: CGFloat, color: Int, at position: SCNVector3, in parent: SCNNode) {
        let cylinder = SCNCylinder(radius: radius, height: height)
        cylinder.radialSegmentCount = 12
        attach(cylinder, color: color, at: position, to: parent)
    }

    func miniaturize(_ province: String) -> SCNNode? {
        let model = SCNNode()
        switch province {
        case "四川":
            let ivory = 0xFFF1D8, ink = 0x273A34
            let unit = SCNVector3(1, 1, 1)
            pebble(0.225, ivory, 0, 0.24, 0, SCNVector3(1, 1.13, 0.87), in: model)
            for sign: Float in [-1, 1] {
                pebble(0.085, ink, sign * 0.16, 0.1, 0.08, SCNVector3(1, 0.95, 1.3), in: model)
                pebble(0.08, ink, sign * 0.185, 0.28, 0.06, SCNVector3(0.9, 1.25, 1), in: model)
            }
            let head = SCNNode()
            head.position.y = 0.48
            model.addChildNode(head)
            pebble(0.235, ivory, 0, 0, 0.025, SCNVector3(1.1, 0.94, 0.92), in: head)
            for sign: Float in [-1, 1] {
                pebble(0.08, ink, sign * 0.18, 0.155, 0.015, unit, in: head)
                let eye = pebble(0.067, ink, sign * 0.105, 0.053, 0.2, SCNVector3(0.85, 1.18, 0.6), in: head)
                eye.eulerAngles.z = -sign * 0.45
                pebble(0.013, ivory, sign * 0.102, 0.064, 0.238, unit, in: head)
            }
            pebble(0.045, ink, 0, -0.012, 0.231, SCNVector3(1, 0.66, 0.6), in: head)
            for i in 0...2 {
                let x = Float(i) * 0.06 - 0.38
                let y: Float = 0.21 + Float(i % 2) * 0.09
                cylinder(0.018, height: CGFloat(y * 2), color: 0x6F9254, at: SCNVector3(x, y, 0), in: model)
                let leaf = pebble(0.09, 0x719552, x - 0.035, y * 1.8, 0, SCNVector3(1, 0.28, 0.5), in: model)
                leaf.eulerAngles.z = -0.6
            }
            let tilt = SCNAction.rotateBy(x: 0, y: 0.17, z: 0.055, duration: 1.4)
            tilt.timingMode = .easeInEaseOut
            animatedNodes.append((head, .repeatForever(.sequence([tilt, tilt.reversed(), .wait(duration: 2.8)]))))
        case "北京", "浙江":
            buildPagoda(temple: province == "北京", in: model)
        case "西藏", "新疆", "云南":
            let snow = province != "新疆"
            let peaks: [(Float, Float, Float)] = [(-0.34, 0.1, 0.47), (0, -0.1, 0.84), (0.31, 0.07, 0.52)]
            for (i, peak) in peaks.enumerated() {
                let mountain = sculptedPeak(height: peak.2, snowy: snow)
                mountain.eulerAngles.y = Float(i) * 1.8
                mountain.position = SCNVector3(peak.0, 0, peak.1)
                model.addChildNode(mountain)
            }
        case "上海":
            cylinder(0.055, height: 0.70, color: 0xEADCC0, at: SCNVector3(0, 0.35, 0), in: model)
            cylinder(0.018, height: 0.36, color: 0xA16862, at: SCNVector3(0, 0.79, 0), in: model)
            for (height, radius) in [(0.30, 0.15), (0.64, 0.095)] {
                pebble(CGFloat(radius), 0xBD7074, 0, Float(height), 0, SCNVector3(1, 0.88, 1), in: model)
            }
            for i in 0..<3 {
                let angle = Float(i) * 2 * .pi / 3
                let leg = SCNCylinder(radius: 0.025, height: 0.30)
                let node = attach(leg, color: 0xD9C5A5, at: SCNVector3(cos(angle) * 0.09, 0.13, sin(angle) * 0.09), to: model)
                node.eulerAngles = SCNVector3(sin(angle) * -0.5, 0, cos(angle) * 0.5)
            }
        case "广西":
            for (x, h) in [(-0.28, 0.32), (-0.07, 0.56), (0.15, 0.43), (0.31, 0.26)] {
                pebble(0.18, x < 0 ? 0x66936C : 0x7EAA72, Float(x), Float(h) * 0.43, Float(abs(x)) * 0.15,
                       SCNVector3(1, Float(h) * 3.12, 0.85), in: model)
            }
        case "内蒙古":
            let turbine = SCNCone(topRadius: 0.027, bottomRadius: 0.052, height: 0.59)
            attach(turbine, color: 0xDFD7AD, at: SCNVector3(0, 0.295, 0), to: model)
            let rotor = SCNNode()
            rotor.position = SCNVector3(0, 0.57, 0.045)
            model.addChildNode(rotor)
            for index in 0..<3 {
                let spoke = SCNNode()
                spoke.eulerAngles.z = Float(index) * 2 * .pi / 3
                rotor.addChildNode(spoke)
                pebble(0.14, 0xF5E7BF, 0, 0.15, 0, SCNVector3(0.31, 1.12, 0.15), in: spoke)
            }
            pebble(0.045, 0xB87E4F, 0, 0, 0.018, SCNVector3(1, 1, 0.7), in: rotor)
            let breeze = SCNAction.rotateBy(x: 0, y: 0, z: 2 * .pi, duration: 10)
            animatedNodes.append((rotor, .repeatForever(breeze)))
        case "黑龙江":
            for (i, x) in [-0.20, 0.02, 0.22].enumerated() {
                let height = 0.34 + 0.11 * CGFloat(i % 2)
                cylinder(0.035, height: 0.17, color: 0x886C48, at: SCNVector3(Float(x), 0.085, 0), in: model)
                let leaves = SCNCone(topRadius: 0, bottomRadius: height * 0.41, height: height)
                leaves.radialSegmentCount = 7
                attach(leaves, color: [0x4E7C62, 0x648969, 0x75916B][i],
                       at: SCNVector3(Float(x), 0.13 + Float(height) * 0.5, 0), to: model)
            }
        default: return nil
        }
        return ["四川", "内蒙古"].contains(province) ? model : model.flattenedClone()
    }
}


private extension ProvinceDiorama {
    /// Continuous swept eaves. Two samples per facet lift the corners of the octagonal roofs.
    func roof(radius: Float, height: Float, temple: Bool) -> SCNNode {
        let count = temple ? 32 : 16
        var body: [SIMD3<Float>] = []
        var edge: [SIMD3<Float>] = []
        func ring(_ index: Int, _ fraction: Float, _ y: Float, lift: Float = 0) -> SIMD3<Float> {
            let angle = Float(index) * 2 * .pi / Float(count)
            let corner: Float = !temple && index.isMultiple(of: 2) ? 1 : 0
            let r = radius * fraction * (temple || corner == 1 ? 1 : cos(.pi / 8))
            return SIMD3(cos(angle) * r, height * y + lift * corner, sin(angle) * r)
        }
        for i in 0..<count {
            let j = i + 1
            let lift = temple ? 0 : radius * 0.13
            let lip = ring(i, 1, 0, lift: lift), nextLip = ring(j, 1, 0, lift: lift)
            let low = ring(i, 0.985, -0.12, lift: lift), nextLow = ring(j, 0.985, -0.12, lift: lift)
            edge += [lip, nextLow, low, lip, nextLip, nextLow]
            let mid = ring(i, 0.53, 0.31), nextMid = ring(j, 0.53, 0.31)
            let top = ring(i, 0.11, 1), nextTop = ring(j, 0.11, 1)
            body += [lip, mid, nextLip, mid, nextMid, nextLip, mid, top, nextMid, top, nextTop, nextMid]
        }
        let node = SCNNode()
        node.addChildNode(facets(body, tint: temple ? 0x397E87 : 0x445F60))
        node.addChildNode(facets(edge, tint: 0xE1B26F))
        return node
    }

    func buildPagoda(temple: Bool, in model: SCNNode) {
        let steps: [(CGFloat, Float)] = [(0.42, 0.028), (0.35, 0.075)]
        for (r, y) in steps {
            cylinder(r, height: 0.055, color: 0xDDCCA7, at: SCNVector3(0, y, 0), in: model)
        }
        let levels = temple ? 3 : 4
        var floor: Float = 0.10
        for i in 0..<levels {
            let taper = 1 - Float(i) * (temple ? 0.19 : 0.14)
            let radius: Float = (temple ? 0.45 : 0.385) * taper
            let wallHeight: Float = temple && i == 0 ? 0.21 : 0.15 * taper
            // A smaller drum leaves a genuine open colonnade below each roof.
            cylinder(CGFloat(radius) * 0.47, height: CGFloat(wallHeight), color: temple ? 0x913E31 : 0xCBA463,
                     at: SCNVector3(0, floor + wallHeight / 2, 0), in: model)
            for post in 0..<8 {
                let angle = Float(post) * .pi / 4
                let r = radius * 0.72
                cylinder(CGFloat(radius * 0.065), height: CGFloat(wallHeight), color: 0xAA4F3D,
                         at: SCNVector3(cos(angle) * r, floor + wallHeight / 2, sin(angle) * r), in: model)
            }
            let eave = roof(radius: radius, height: (temple ? 0.25 : 0.20) * taper, temple: temple)
            eave.position.y = floor + wallHeight
            model.addChildNode(eave)
            floor += wallHeight + (temple ? 0.16 : 0.132) * taper
        }
        cylinder(0.024, height: 0.14, color: 0xCCA05D, at: SCNVector3(0, floor + 0.07, 0), in: model)
        pebble(0.044, 0xE7BC66, 0, floor + 0.15, 0, SCNVector3(1, 1.12, 1), in: model)
    }

    func sculptedPeak(height: Float, snowy: Bool) -> SCNNode {
        var rock: [SIMD3<Float>] = [], tip: [SIMD3<Float>] = []
        let variations: [Float] = [0.91, 0.86, 1.12, 0.83, 1.05, 0.88, 1.14, 0.87]
        let snowline: [Float] = [0.58, 0.67, 0.53, 0.73, 0.56, 0.71, 0.63, 0.72]
        let peak = SIMD3<Float>(-height * 0.10, height, 0.03)
        let feet: [SIMD3<Float>] = variations.enumerated().map { i, scale in
            let angle = Float(i) * .pi / 4
            return SIMD3(cos(angle) * height * 0.70 * scale, 0, sin(angle) * height * 0.54 * scale)
        }
        for i in feet.indices {
            let j = (i + 1) % feet.count
            let low = feet[i], nextLow = feet[j]
            let near = simd_mix(low, peak, SIMD3(repeating: snowline[i]))
            let far = simd_mix(nextLow, peak, SIMD3(repeating: snowline[j]))
            rock += [low, near, nextLow, near, far, nextLow]
            tip += [near, peak, far]
        }
        let node = SCNNode()
        node.addChildNode(facets(rock, tint: snowy ? 0x72949B : 0xBB864D))
        node.addChildNode(facets(tip, tint: snowy ? 0xF4EEE0 : 0xDBAA68))
        return node
    }

    func facets(_ vertices: [SIMD3<Float>], tint: Int) -> SCNNode {
        var normals: [SCNVector3] = []
        for i in stride(from: 0, to: vertices.count, by: 3) {
            let surface = simd_normalize(simd_cross(vertices[i+1] - vertices[i], vertices[i+2] - vertices[i]))
            normals += Array(repeating: SCNVector3(surface), count: 3)
        }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices.map { SCNVector3($0) }),
                                              SCNGeometrySource(normals: normals)],
                                   elements: [SCNGeometryElement(indices: vertices.indices.map { Int32($0) }, primitiveType: .triangles)])
        let material = Self.material(UIColor(mapRGB: tint))
        material.isDoubleSided = true
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }
}
