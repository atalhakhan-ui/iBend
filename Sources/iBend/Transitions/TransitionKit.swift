import AppKit
import QuartzCore

// MARK: - Direction

/// `.closing` covers the desktop (lid going down); `.opening` uncovers it (lid coming up).
/// Every transition is authored once, in "covered vs. open" terms, and the timeline
/// plays it forwards or backwards — including the stagger order — from that single description.
enum TransitionDirection {
    case opening
    case closing
}

struct TransitionContext {
    var size: CGSize
    var direction: TransitionDirection
    var palette: Palette
    var duration: CFTimeInterval
    var scale: CGFloat
    var startTime: CFTimeInterval
    var mode: TimelineMode = .animate
    var isPreview: Bool = false
}

// MARK: - Curves

enum Curve {
    case linear, standard, emphasized, easeOut, easeIn, snappy, gentle, anticipate

    /// Cubic-bezier control points. Held here rather than baked into a
    /// `CAMediaTimingFunction` so the offscreen renderer can evaluate the same curve.
    var points: (Double, Double, Double, Double) {
        switch self {
        case .linear:     return (0, 0, 1, 1)
        case .standard:   return (0.4, 0, 0.2, 1)
        case .emphasized: return (0.2, 0, 0, 1)
        case .easeOut:    return (0, 0, 0.2, 1)
        case .easeIn:     return (0.5, 0, 1, 1)
        case .snappy:     return (0.16, 1.06, 0.3, 1)
        case .gentle:     return (0.45, 0.05, 0.25, 1)
        case .anticipate: return (0.7, -0.35, 0.25, 1)
        }
    }

    var fn: CAMediaTimingFunction {
        let p = points
        return CAMediaTimingFunction(controlPoints: Float(p.0), Float(p.1), Float(p.2), Float(p.3))
    }

    /// Solves the curve for y at a given x, the way Core Animation does, so the offscreen
    /// renderer can sample the same easing.
    func value(at x: Double) -> Double {
        let (x1, y1, x2, y2) = points
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }

        func bezier(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let mt = 1 - t
            return 3 * mt * mt * t * a + 3 * mt * t * t * b + t * t * t
        }
        func slope(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let mt = 1 - t
            return 3 * mt * mt * a + 6 * mt * t * (b - a) + 3 * t * t * (1 - b)
        }

        var t = x
        for _ in 0..<8 {
            let d = slope(t, x1, x2)
            if abs(d) < 1e-6 { break }
            t = min(max(t - (bezier(t, x1, x2) - x) / d, 0), 1)
        }
        return bezier(t, y1, y2)
    }
}

/// How a timeline realises itself: as live Core Animation, or as one evaluated frame.
/// The snapshot path exists because `CALayer.render(in:)` draws model values only.
enum TimelineMode: Equatable {
    case animate
    case snapshot(Double)
}

// MARK: - Timeline

/// Builds a layer tree plus its animations. Transitions describe the two end states
/// (`covered` and `open`) and a normalised slice of the timeline (`begin`/`span`);
/// the timeline resolves that into concrete Core Animation objects for the direction
/// being played, reversing both the values and the stagger when opening.
final class Timeline {
    let ctx: TransitionContext
    let root: CALayer
    private var counter = 0

    var size: CGSize { ctx.size }
    var w: CGFloat { ctx.size.width }
    var h: CGFloat { ctx.size.height }
    var bounds: CGRect { CGRect(origin: .zero, size: ctx.size) }
    var center: CGPoint { CGPoint(x: w / 2, y: h / 2) }
    var diagonal: CGFloat { sqrt(w * w + h * h) }
    var colors: [CGColor] { ctx.palette.colors }

    init(ctx: TransitionContext, root: CALayer) {
        self.ctx = ctx
        self.root = root
    }

    /// Samples the palette as a continuous ramp. Grid-based transitions use this so a
    /// field of tiles reads as one surface rather than a checkerboard of flat colours.
    func ramp(_ p: Double) -> CGColor {
        let c = colors
        guard c.count > 1 else { return c[0] }
        let x = min(max(p, 0), 1) * Double(c.count - 1)
        let i = min(Int(x), c.count - 2)
        return Palette.mix(c[i], c[i + 1], CGFloat(x - Double(i)))
    }

    func color(_ i: Int) -> CGColor {
        let c = colors
        return c[((i % c.count) + c.count) % c.count]
    }

    // MARK: Animation

    @discardableResult
    func add(_ layer: CALayer,
             _ keyPath: String,
             covered: Any,
             open: Any,
             begin: Double = 0,
             span: Double = 1,
             curve: Curve = .emphasized) -> CABasicAnimation {
        let (b, s) = slice(begin, span)
        let from: Any = ctx.direction == .closing ? open : covered
        let to: Any   = ctx.direction == .closing ? covered : open

        if case .snapshot(let progress) = ctx.mode {
            layer.setValue(Interp.between(from, to, curve.value(at: local(progress, b, s))),
                           forKeyPath: keyPath)
            return CABasicAnimation(keyPath: keyPath)
        }

        let a = CABasicAnimation(keyPath: keyPath)
        a.fromValue = from
        a.toValue = to
        a.beginTime = ctx.startTime + b * ctx.duration
        a.duration = max(s * ctx.duration, 0.0001)
        a.timingFunction = curve.fn
        a.fillMode = .both
        a.isRemovedOnCompletion = false
        attach(a, to: layer, keyPath: keyPath)
        layer.setValue(to, forKeyPath: keyPath)
        return a
    }

    /// Keyframe variant. `values` is always authored covered-first.
    @discardableResult
    func addKeyframe(_ layer: CALayer,
                     _ keyPath: String,
                     values: [Any],
                     begin: Double = 0,
                     span: Double = 1,
                     curve: Curve = .emphasized) -> CAKeyframeAnimation {
        let (b, s) = slice(begin, span)
        let ordered = ctx.direction == .closing ? values.reversed().map { $0 } : values

        if case .snapshot(let progress) = ctx.mode {
            layer.setValue(Interp.inSequence(ordered, curve.value(at: local(progress, b, s))),
                           forKeyPath: keyPath)
            return CAKeyframeAnimation(keyPath: keyPath)
        }

        let a = CAKeyframeAnimation(keyPath: keyPath)
        a.values = ordered
        a.beginTime = ctx.startTime + b * ctx.duration
        a.duration = max(s * ctx.duration, 0.0001)
        a.timingFunction = curve.fn
        a.calculationMode = .linear
        a.fillMode = .both
        a.isRemovedOnCompletion = false
        attach(a, to: layer, keyPath: keyPath)
        layer.setValue(ordered.last, forKeyPath: keyPath)
        return a
    }

    /// `path` needs its own entry point: CGPath does not survive KVC round-tripping.
    func addPath(_ shape: CAShapeLayer,
                 covered: CGPath,
                 open: CGPath,
                 begin: Double = 0,
                 span: Double = 1,
                 curve: Curve = .emphasized) {
        let (b, s) = slice(begin, span)
        let from = ctx.direction == .closing ? open : covered
        let to   = ctx.direction == .closing ? covered : open

        if case .snapshot(let progress) = ctx.mode {
            shape.path = Interp.path(from, to, curve.value(at: local(progress, b, s)))
            return
        }

        let a = CABasicAnimation(keyPath: "path")
        a.fromValue = from
        a.toValue = to
        a.beginTime = ctx.startTime + b * ctx.duration
        a.duration = max(s * ctx.duration, 0.0001)
        a.timingFunction = curve.fn
        a.fillMode = .both
        a.isRemovedOnCompletion = false
        attach(a, to: shape, keyPath: "path")
        shape.path = to
    }

    /// Where a global progress value sits inside one animation's own slice.
    func local(_ progress: Double, _ begin: Double, _ span: Double) -> Double {
        min(max((progress - begin) / max(span, 0.0001), 0), 1)
    }

    private func slice(_ begin: Double, _ span: Double) -> (Double, Double) {
        let b = max(0, min(1, begin))
        let s = max(0.0001, min(1 - b, span))
        return ctx.direction == .opening ? (1 - b - s, s) : (b, s)
    }

    private func attach(_ a: CAAnimation, to layer: CALayer, keyPath: String) {
        counter += 1
        layer.add(a, forKey: "\(keyPath)#\(counter)")
    }

    // MARK: Layer factories

    @discardableResult
    func solid(_ frame: CGRect, _ color: CGColor, parent: CALayer? = nil) -> CALayer {
        let l = CALayer()
        l.frame = frame
        l.backgroundColor = color
        l.allowsEdgeAntialiasing = true
        (parent ?? root).addSublayer(l)
        return l
    }

    @discardableResult
    func gradient(_ frame: CGRect,
                  _ cgColors: [CGColor],
                  from start: CGPoint = CGPoint(x: 0, y: 0),
                  to end: CGPoint = CGPoint(x: 1, y: 1),
                  type: CAGradientLayerType = .axial,
                  locations: [NSNumber]? = nil,
                  parent: CALayer? = nil) -> CAGradientLayer {
        let g = CAGradientLayer()
        g.frame = frame
        g.colors = cgColors
        g.startPoint = start
        g.endPoint = end
        g.type = type
        g.locations = locations
        (parent ?? root).addSublayer(g)
        return g
    }

    /// A soft round light source. Built from alpha stops rather than a blur filter so it
    /// stays on the GPU compositor at full-screen size.
    @discardableResult
    func glow(center c: CGPoint,
              radius: CGFloat,
              color: CGColor,
              softness: Double = 1.0,
              parent: CALayer? = nil) -> CAGradientLayer {
        let stops: [NSNumber] = [0, NSNumber(value: 0.22 * softness), NSNumber(value: 0.55 * softness), 1]
        let g = CAGradientLayer()
        g.frame = CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)
        g.type = .radial
        g.startPoint = CGPoint(x: 0.5, y: 0.5)
        g.endPoint = CGPoint(x: 1, y: 1)
        g.locations = stops
        g.colors = [
            color.withAlpha(1.0),
            color.withAlpha(0.72),
            color.withAlpha(0.22),
            color.withAlpha(0.0)
        ]
        (parent ?? root).addSublayer(g)
        return g
    }

    @discardableResult
    func shape(_ path: CGPath, fill: CGColor?, parent: CALayer? = nil) -> CAShapeLayer {
        let s = CAShapeLayer()
        s.frame = bounds
        s.path = path
        s.fillColor = fill
        s.strokeColor = nil
        (parent ?? root).addSublayer(s)
        return s
    }

    @discardableResult
    func group(_ frame: CGRect? = nil, parent: CALayer? = nil) -> CALayer {
        let l = CALayer()
        l.frame = frame ?? bounds
        (parent ?? root).addSublayer(l)
        return l
    }

    /// Full-bleed palette wash. Most transitions fade one of these in late (closing) so the
    /// screen is guaranteed fully opaque by the time the display actually sleeps.
    @discardableResult
    func backdrop(_ cgColors: [CGColor]? = nil,
                  from start: CGPoint = CGPoint(x: 0, y: 0),
                  to end: CGPoint = CGPoint(x: 1, y: 1)) -> CAGradientLayer {
        gradient(bounds, cgColors ?? colors, from: start, to: end)
    }

    /// Fades a guaranteed-opaque wash in over the tail of the close (and out over the head
    /// of the open), so no transition can ever leave a gap on screen.
    func sealBackdrop(_ cgColors: [CGColor]? = nil, at begin: Double = 0.7) {
        let g = backdrop(cgColors)
        add(g, "opacity", covered: 1.0, open: 0.0, begin: begin, span: 1 - begin, curve: .easeOut)
    }
}

// MARK: - Transition

protocol Transition {
    var id: String { get }
    var title: String { get }
    var blurb: String { get }
    var baseDuration: CFTimeInterval { get }
    func build(_ t: Timeline)

    /// A live view layered behind the transition's layers. Only blur transitions need
    /// one: a CALayer cannot blur what is behind the window, so the real backdrop blur
    /// has to come from `NSVisualEffectView` and `backgroundFilters`.
    func makeBackdrop(_ ctx: TransitionContext) -> NSView?
}

extension Transition {
    var baseDuration: CFTimeInterval { 0.95 }
    func makeBackdrop(_ ctx: TransitionContext) -> NSView? { nil }
}

enum TransitionRenderer {
    static func makeLayer(_ transition: Transition, ctx: TransitionContext) -> CALayer {
        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: ctx.size)
        root.masksToBounds = true
        root.isGeometryFlipped = true   // y grows downward, like every other UI coordinate space
        root.backgroundColor = NSColor.clear.cgColor

        let timeline = Timeline(ctx: ctx, root: root)
        transition.build(timeline)
        applyScale(ctx.scale, to: root)
        return root
    }

    private static func applyScale(_ scale: CGFloat, to layer: CALayer) {
        layer.contentsScale = scale
        if let shape = layer as? CAShapeLayer { shape.rasterizationScale = scale }
        layer.sublayers?.forEach { applyScale(scale, to: $0) }
    }
}

// MARK: - Geometry helpers

enum Geo {
    /// A pie wedge sampled at a fixed point count, so two wedges of different angles
    /// still interpolate smoothly as a `path` animation.
    static func wedge(center: CGPoint, radius: CGFloat, angle: CGFloat, samples: Int = 96) -> CGPath {
        let p = CGMutablePath()
        p.move(to: center)
        let a = max(angle, 0.00001)
        for i in 0...samples {
            let theta = -CGFloat.pi / 2 + a * CGFloat(i) / CGFloat(samples)
            p.addLine(to: CGPoint(x: center.x + cos(theta) * radius, y: center.y + sin(theta) * radius))
        }
        p.closeSubpath()
        return p
    }

    /// A wobbling blob, also fixed-sample so radii can be animated by path interpolation.
    static func blob(center: CGPoint, radius: CGFloat, wobble: CGFloat, phase: CGFloat, lobes: Int = 5, samples: Int = 120) -> CGPath {
        let p = CGMutablePath()
        for i in 0...samples {
            let theta = CGFloat(i) / CGFloat(samples) * .pi * 2
            let r = radius * (1 + wobble * sin(theta * CGFloat(lobes) + phase) * 0.5
                                + wobble * sin(theta * CGFloat(lobes + 3) - phase * 1.7) * 0.25)
            let pt = CGPoint(x: center.x + cos(theta) * r, y: center.y + sin(theta) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// A rect with a hole in it (even-odd), for iris-style reveals.
    static func rectWithHole(_ rect: CGRect, center: CGPoint, radius: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.addRect(rect)
        let r = max(radius, 0.0001)
        p.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        return p
    }

    /// Flat-top hexagon: the first vertex points along +x. The hex grid spaces columns
    /// by 1.5r and rows by √3·r, which only tiles without gaps in this orientation.
    static func hexagon(center: CGPoint, radius: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<6 {
            let theta = CGFloat(i) / 6 * .pi * 2
            let pt = CGPoint(x: center.x + cos(theta) * radius, y: center.y + sin(theta) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    static func transform(translate: CGPoint = .zero,
                          scale: CGFloat = 1,
                          rotate z: CGFloat = 0,
                          rotateX x: CGFloat = 0,
                          rotateY y: CGFloat = 0,
                          perspective: CGFloat = 0) -> CATransform3D {
        var m = CATransform3DIdentity
        if perspective != 0 { m.m34 = -1 / perspective }
        m = CATransform3DTranslate(m, translate.x, translate.y, 0)
        if x != 0 { m = CATransform3DRotate(m, x, 1, 0, 0) }
        if y != 0 { m = CATransform3DRotate(m, y, 0, 1, 0) }
        if z != 0 { m = CATransform3DRotate(m, z, 0, 0, 1) }
        if scale != 1 { m = CATransform3DScale(m, scale, scale, 1) }
        return m
    }
}

/// Deterministic randomness, so a transition looks identical every time it plays
/// (and identical in the gallery preview).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
    mutating func double(_ lo: Double = 0, _ hi: Double = 1) -> Double {
        lo + (Double(next() % 1_000_000) / 1_000_000) * (hi - lo)
    }
    mutating func cg(_ lo: CGFloat = 0, _ hi: CGFloat = 1) -> CGFloat { CGFloat(double(Double(lo), Double(hi))) }
}

extension CGColor {
    func withAlpha(_ a: CGFloat) -> CGColor { copy(alpha: a) ?? self }
}
