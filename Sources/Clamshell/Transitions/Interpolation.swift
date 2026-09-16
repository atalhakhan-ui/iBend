import AppKit
import QuartzCore

/// Value interpolation for the offscreen renderer.
///
/// `CALayer.render(in:)` draws model values and ignores running animations, so to capture
/// a transition mid-flight the timeline evaluates itself and writes the interpolated value
/// straight onto the layer. Live playback never goes through here.
enum Interp {

    static func between(_ a: Any, _ b: Any, _ t: Double) -> Any {
        // NSNumber is an NSValue subclass, so it has to be tested first.
        if let x = a as? NSNumber, let y = b as? NSNumber {
            return NSNumber(value: x.doubleValue + (y.doubleValue - x.doubleValue) * t)
        }
        if let x = a as? NSValue, let y = b as? NSValue {
            let type = String(cString: x.objCType)
            if type.hasPrefix("{CGPoint") {
                let p = x.pointValue, q = y.pointValue
                return NSValue(point: CGPoint(x: lerp(p.x, q.x, t), y: lerp(p.y, q.y, t)))
            }
            if type.hasPrefix("{CGSize") {
                let p = x.sizeValue, q = y.sizeValue
                return NSValue(size: CGSize(width: lerp(p.width, q.width, t), height: lerp(p.height, q.height, t)))
            }
            // Everything else in this codebase that travels as an NSValue is a transform.
            return NSValue(caTransform3D: flattened(lerp(x.caTransform3DValue, y.caTransform3DValue, t)))
        }
        return t < 0.5 ? a : b
    }

    static func inSequence(_ values: [Any], _ t: Double) -> Any {
        guard values.count > 1 else { return values.first ?? 0 }
        let pos = min(max(t, 0), 1) * Double(values.count - 1)
        let i = min(Int(pos), values.count - 2)
        return between(values[i], values[i + 1], pos - Double(i))
    }

    static func inSequencePaths(_ values: [CGPath], _ t: Double) -> CGPath? {
        guard values.count > 1 else { return values.first }
        let pos = min(max(t, 0), 1) * Double(values.count - 1)
        let i = min(Int(pos), values.count - 2)
        return path(values[i], values[i + 1], pos - Double(i))
    }

    /// Structural path interpolation. Every animated path in this project is generated with
    /// a fixed sample count precisely so this works; mismatched paths fall back to a cut.
    static func path(_ a: CGPath, _ b: CGPath, _ t: Double) -> CGPath {
        let ea = elements(of: a), eb = elements(of: b)
        guard ea.count == eb.count else { return t < 0.5 ? a : b }

        let out = CGMutablePath()
        for (x, y) in zip(ea, eb) {
            guard x.type == y.type else { return t < 0.5 ? a : b }
            let p = zip(x.points, y.points).map {
                CGPoint(x: lerp($0.x, $1.x, t), y: lerp($0.y, $1.y, t))
            }
            switch x.type {
            case .moveToPoint:        out.move(to: p[0])
            case .addLineToPoint:     out.addLine(to: p[0])
            case .addQuadCurveToPoint: out.addQuadCurve(to: p[1], control: p[0])
            case .addCurveToPoint:    out.addCurve(to: p[2], control1: p[0], control2: p[1])
            case .closeSubpath:       out.closeSubpath()
            @unknown default:         break
            }
        }
        return out
    }

    // MARK: Internals

    private struct Element {
        let type: CGPathElementType
        let points: [CGPoint]
    }

    private static func elements(of path: CGPath) -> [Element] {
        var out: [Element] = []
        path.applyWithBlock { pointer in
            let element = pointer.pointee
            let count: Int
            switch element.type {
            case .moveToPoint, .addLineToPoint: count = 1
            case .addQuadCurveToPoint:          count = 2
            case .addCurveToPoint:              count = 3
            case .closeSubpath:                 count = 0
            @unknown default:                   count = 0
            }
            var points: [CGPoint] = []
            points.reserveCapacity(count)
            for i in 0..<count { points.append(element.points[i]) }
            out.append(Element(type: element.type, points: points))
        }
        return out
    }

    /// `CALayer.render(in:)` silently falls back to identity for any transform it cannot
    /// express as an affine one — which includes every 3D rotation and every perspective
    /// term. Projecting onto the affine shadow keeps those layers visible in the offscreen
    /// render (a rotation reads as a squash) instead of snapping back into place.
    private static func flattened(_ m: CATransform3D) -> CATransform3D {
        CATransform3DMakeAffineTransform(
            CGAffineTransform(a: m.m11, b: m.m12, c: m.m21, d: m.m22, tx: m.m41, ty: m.m42)
        )
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(t)
    }

    private static func lerp(_ a: CATransform3D, _ b: CATransform3D, _ t: Double) -> CATransform3D {
        var m = a
        m.m11 = lerp(a.m11, b.m11, t); m.m12 = lerp(a.m12, b.m12, t)
        m.m13 = lerp(a.m13, b.m13, t); m.m14 = lerp(a.m14, b.m14, t)
        m.m21 = lerp(a.m21, b.m21, t); m.m22 = lerp(a.m22, b.m22, t)
        m.m23 = lerp(a.m23, b.m23, t); m.m24 = lerp(a.m24, b.m24, t)
        m.m31 = lerp(a.m31, b.m31, t); m.m32 = lerp(a.m32, b.m32, t)
        m.m33 = lerp(a.m33, b.m33, t); m.m34 = lerp(a.m34, b.m34, t)
        m.m41 = lerp(a.m41, b.m41, t); m.m42 = lerp(a.m42, b.m42, t)
        m.m43 = lerp(a.m43, b.m43, t); m.m44 = lerp(a.m44, b.m44, t)
        return m
    }
}
