import AppKit
import QuartzCore

@inline(__always) func nv(_ p: CGPoint) -> NSValue { NSValue(point: p) }
@inline(__always) func nv(_ m: CATransform3D) -> NSValue { NSValue(caTransform3D: m) }
@inline(__always) func nv(_ r: CGRect) -> NSValue { NSValue(rect: r) }

extension Timeline {
    /// Path keyframes, authored covered-first like every other timeline call.
    func addPathKeyframe(_ shape: CAShapeLayer,
                         values: [CGPath],
                         begin: Double = 0,
                         span: Double = 1,
                         curve: Curve = .emphasized) {
        let ordered = ctx.direction == .closing ? values.reversed().map { $0 } : values
        let b: Double
        let s = max(0.0001, min(1 - max(0, min(1, begin)), span))
        b = ctx.direction == .opening ? 1 - max(0, min(1, begin)) - s : max(0, min(1, begin))

        if case .snapshot(let progress) = ctx.mode {
            shape.path = Interp.inSequencePaths(ordered, curve.value(at: local(progress, b, s)))
            return
        }

        let a = CAKeyframeAnimation(keyPath: "path")
        a.values = ordered
        a.beginTime = ctx.startTime + b * ctx.duration
        a.duration = max(s * ctx.duration, 0.0001)
        a.timingFunction = curve.fn
        a.calculationMode = .linear
        a.fillMode = .both
        a.isRemovedOnCompletion = false
        shape.add(a, forKey: "pathKeyframe-\(ObjectIdentifier(shape).hashValue)-\(values.count)")
        shape.path = ordered.last
    }

    /// Convenience: fade + scale, the most common pairing.
    func fadeScale(_ layer: CALayer,
                   openScale: CGFloat,
                   rotate: CGFloat = 0,
                   begin: Double = 0,
                   span: Double = 1,
                   curve: Curve = .emphasized) {
        add(layer, "transform",
            covered: nv(Geo.transform(scale: 1, rotate: 0)),
            open: nv(Geo.transform(scale: openScale, rotate: rotate)),
            begin: begin, span: span, curve: curve)
        add(layer, "opacity", covered: Float(1), open: Float(0), begin: begin, span: span, curve: .easeIn)
    }
}

extension Geo {
    /// Wedge with an explicit start angle, sampled at a fixed point count so two wedges
    /// of different sweeps still interpolate as a path animation.
    static func wedge(center: CGPoint, radius: CGFloat, start: CGFloat, sweep: CGFloat, samples: Int = 96) -> CGPath {
        let p = CGMutablePath()
        p.move(to: center)
        let a = max(sweep, 0.00001)
        for i in 0...samples {
            let theta = start + a * CGFloat(i) / CGFloat(samples)
            p.addLine(to: CGPoint(x: center.x + cos(theta) * radius, y: center.y + sin(theta) * radius))
        }
        p.closeSubpath()
        return p
    }

    static func roundedRect(_ r: CGRect, radius: CGFloat) -> CGPath {
        CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }
}
