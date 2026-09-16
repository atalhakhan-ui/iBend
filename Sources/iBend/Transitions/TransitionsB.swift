import AppKit
import QuartzCore

// MARK: - 11. Ripple

/// The wash retreats to a point while rings run outward past it.
struct RippleTransition: Transition {
    let id = "ripple"
    let title = "Ripple"
    let blurb = "Rings run outward as the colour retreats."
    var baseDuration: CFTimeInterval { 1.05 }

    func build(_ t: Timeline) {
        let wash = t.backdrop([t.color(1), t.color(0)])
        let maxR = t.diagonal * 0.62

        let mask = CAShapeLayer()
        mask.frame = t.bounds
        mask.fillColor = NSColor.black.cgColor
        wash.mask = mask
        t.addPath(mask,
                  covered: circle(t.center, maxR),
                  open: circle(t.center, 0.001),
                  curve: .emphasized)

        for i in 0..<5 {
            let ring = CAShapeLayer()
            ring.frame = t.bounds
            ring.fillColor = nil
            ring.strokeColor = t.color(2 + i % 2).withAlpha(0.7)
            ring.lineWidth = CGFloat(6 - i)
            t.root.addSublayer(ring)

            let delay = 0.10 * Double(i)
            t.addPath(ring,
                      covered: circle(t.center, maxR * 0.1),
                      open: circle(t.center, maxR * 1.05),
                      begin: delay, span: max(0.35, 0.85 - delay), curve: .easeOut)
            t.addKeyframe(ring, "opacity",
                          values: [Float(0), Float(0.75), Float(0)],
                          begin: delay, span: max(0.35, 0.85 - delay), curve: .linear)
        }
    }

    private func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil)
    }
}

// MARK: - 12. Warp

/// Light streaks accelerating out of the centre.
struct WarpTransition: Transition {
    let id = "warp"
    let title = "Warp"
    let blurb = "Light streaks accelerate out of the centre."
    var baseDuration: CFTimeInterval { 0.9 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.color(0), t.color(1)], at: 0.62)

        var rng = SeededRNG(0x2718)
        let count = 90
        let maxR = t.diagonal * 0.62

        for i in 0..<count {
            let angle = rng.cg(0, .pi * 2)
            let len = rng.cg(t.w * 0.05, t.w * 0.22)
            let thickness = rng.cg(1.5, 4.5)
            let nearR = rng.cg(0.02, 0.22) * maxR
            let farR = maxR * rng.cg(0.95, 1.35)

            let streak = CALayer()
            streak.bounds = CGRect(x: 0, y: 0, width: len, height: thickness)
            streak.cornerRadius = thickness / 2
            streak.backgroundColor = t.color(1 + i % 3).withAlpha(rng.cg(0.5, 1.0))
            streak.position = CGPoint(x: t.center.x + cos(angle) * nearR, y: t.center.y + sin(angle) * nearR)
            t.root.addSublayer(streak)

            let delay = rng.double(0, 0.30)
            let near = CGPoint(x: t.center.x + cos(angle) * nearR, y: t.center.y + sin(angle) * nearR)
            let far = CGPoint(x: t.center.x + cos(angle) * farR, y: t.center.y + sin(angle) * farR)
            t.add(streak, "position", covered: nv(near), open: nv(far),
                  begin: delay, span: max(0.35, 1 - delay), curve: .easeIn)
            t.add(streak, "transform",
                  covered: nv(Geo.transform(scale: 0.4, rotate: angle)),
                  open: nv(Geo.transform(scale: 2.4, rotate: angle)),
                  begin: delay, span: max(0.35, 1 - delay), curve: .easeIn)
            t.add(streak, "opacity", covered: Float(0.9), open: Float(0),
                  begin: delay, span: 0.3, curve: .easeOut)
        }
    }
}

// MARK: - 13. Fold

/// An accordion of vertical panels folding away, lit from one side.
struct FoldTransition: Transition {
    let id = "fold"
    let title = "Fold"
    let blurb = "Vertical panels fold away like an accordion."
    var baseDuration: CFTimeInterval { 1.05 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.color(1), t.color(2)], at: 0.8)
        let panels = 8
        let pw = t.w / CGFloat(panels)

        for i in 0..<panels {
            let x = CGFloat(i) * pw
            let panel = t.group(CGRect(x: x, y: 0, width: pw + 1.2, height: t.h))
            panel.masksToBounds = true
            panel.anchorPoint = CGPoint(x: i % 2 == 0 ? 0 : 1, y: 0.5)
            panel.position = CGPoint(x: i % 2 == 0 ? x : x + pw, y: t.h / 2)

            _ = t.gradient(CGRect(x: 0, y: 0, width: pw + 1.2, height: t.h),
                           [t.color(1), t.color(2)],
                           from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 1), parent: panel)
            let shade = t.solid(CGRect(x: 0, y: 0, width: pw + 1.2, height: t.h),
                                NSColor.black.withAlphaComponent(i % 2 == 0 ? 0.0 : 0.28).cgColor,
                                parent: panel)

            var open = CATransform3DIdentity
            open.m34 = -1 / 700
            open = CATransform3DRotate(open, (i % 2 == 0 ? 1 : -1) * 1.45, 0, 1, 0)

            let delay = 0.03 * Double(i)
            t.add(panel, "transform", covered: nv(CATransform3DIdentity), open: nv(open),
                  begin: delay, span: max(0.4, 1 - delay), curve: .emphasized)
            t.add(shade, "opacity",
                  covered: Float(i % 2 == 0 ? 0.0 : 0.28), open: Float(0.85),
                  begin: delay, span: max(0.4, 1 - delay), curve: .standard)
            t.add(panel, "opacity", covered: Float(1), open: Float(0),
                  begin: delay, span: 0.3, curve: .easeOut)
        }
    }
}

// MARK: - 14. Glimmer

/// A single diagonal band of light that wipes the screen clean.
struct GlimmerTransition: Transition {
    let id = "glimmer"
    let title = "Glimmer"
    let blurb = "A diagonal band of light wipes the screen."
    var baseDuration: CFTimeInterval { 0.85 }

    func build(_ t: Timeline) {
        let wash = t.backdrop([t.color(1), t.color(0)])
        let d = t.diagonal
        let angle: CGFloat = -0.5
        let dir = CGPoint(x: cos(angle), y: sin(angle))
        let travel = d * 0.62
        let covered = CGPoint(x: t.center.x + dir.x * travel, y: t.center.y + dir.y * travel)
        let open = CGPoint(x: t.center.x - dir.x * travel, y: t.center.y - dir.y * travel)

        // Opaque on one half, clear on the other, with the crossover at the layer's centre.
        let mask = CAGradientLayer()
        mask.bounds = CGRect(x: 0, y: 0, width: d * 4, height: d * 3)
        mask.position = t.center
        mask.startPoint = CGPoint(x: 0, y: 0.5)
        mask.endPoint = CGPoint(x: 1, y: 0.5)
        mask.locations = [0, 0.44, 0.56, 1]
        mask.colors = [
            NSColor.black.cgColor, NSColor.black.cgColor,
            NSColor.clear.cgColor, NSColor.clear.cgColor
        ]
        mask.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        wash.mask = mask
        t.add(mask, "position", covered: nv(covered), open: nv(open), curve: .standard)

        // Specular bar riding the same edge.
        let bar = t.gradient(CGRect(x: 0, y: 0, width: 190, height: d * 3),
                             [t.color(3).withAlpha(0), t.color(3).withAlpha(0.9), t.color(3).withAlpha(0)],
                             from: CGPoint(x: 0, y: 0.5), to: CGPoint(x: 1, y: 0.5))
        bar.position = t.center
        bar.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        t.add(bar, "position", covered: nv(covered), open: nv(open), curve: .standard)
        t.addKeyframe(bar, "opacity", values: [Float(0), Float(1), Float(0)], curve: .linear)
    }
}

// MARK: - 15. Dissolve

/// A fine grain of tiles blinking out at random.
struct DissolveTransition: Transition {
    let id = "dissolve"
    let title = "Dissolve"
    let blurb = "A fine grain of tiles blinks out at random."
    var baseDuration: CFTimeInterval { 0.95 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.ramp(0.1), t.ramp(0.9)], at: 0.82)
        let cols = 26
        let rows = max(10, Int((CGFloat(cols) * t.h / t.w).rounded()))
        let tw = t.w / CGFloat(cols), th = t.h / CGFloat(rows)
        var rng = SeededRNG(0xD155)

        for r in 0..<rows {
            for c in 0..<cols {
                let rect = CGRect(x: CGFloat(c) * tw, y: CGFloat(r) * th, width: tw + 1.2, height: th + 1.2)
                let nx = (CGFloat(c) + 0.5) / CGFloat(cols)
                let ny = (CGFloat(r) + 0.5) / CGFloat(rows)
                let tile = t.solid(rect, t.ramp(Double(nx * 0.5 + ny * 0.5)).withAlpha(0.95))
                let delay = rng.double(0, 0.72)
                t.add(tile, "opacity", covered: Float(1), open: Float(0),
                      begin: delay, span: max(0.14, 0.28), curve: .linear)
            }
        }
    }
}

// MARK: - 16. Halo

/// The restrained one: a breathing wash and a single soft halo.
struct HaloTransition: Transition {
    let id = "halo"
    let title = "Halo"
    let blurb = "A single soft halo breathes and clears."
    var baseDuration: CFTimeInterval { 0.8 }

    func build(_ t: Timeline) {
        let wash = t.backdrop([t.color(0), t.color(1)])
        t.add(wash, "opacity", covered: Float(1), open: Float(0), begin: 0.18, span: 0.82, curve: .standard)
        t.add(wash, "transform",
              covered: nv(CATransform3DIdentity), open: nv(Geo.transform(scale: 1.08)),
              curve: .emphasized)

        let halo = t.glow(center: t.center, radius: t.w * 0.34, color: t.color(3), softness: 1.15)
        t.add(halo, "opacity", covered: Float(0.55), open: Float(0), begin: 0, span: 0.6, curve: .easeOut)
        t.add(halo, "transform",
              covered: nv(Geo.transform(scale: 0.85)), open: nv(Geo.transform(scale: 1.6)),
              curve: .emphasized)
    }
}

// MARK: - 17. Ink

/// Blots of colour merging into, or lifting off, the surface.
struct InkTransition: Transition {
    let id = "ink"
    let title = "Ink"
    let blurb = "Blots of colour merge and lift away."
    var baseDuration: CFTimeInterval { 1.1 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.color(1), t.color(2)], at: 0.80)
        var rng = SeededRNG(0x9A17)
        let count = 34

        for i in 0..<count {
            let radius = t.w * rng.cg(0.10, 0.26)
            let cx = t.w * rng.cg(-0.05, 1.05)
            let cy = t.h * rng.cg(-0.05, 1.05)
            let blot = CAShapeLayer()
            blot.bounds = CGRect(x: 0, y: 0, width: radius * 2.6, height: radius * 2.6)
            blot.position = CGPoint(x: cx, y: cy)
            blot.path = Geo.blob(center: CGPoint(x: radius * 1.3, y: radius * 1.3),
                                 radius: radius, wobble: rng.cg(0.08, 0.22),
                                 phase: rng.cg(0, 6), lobes: Int(rng.cg(4, 8)))
            blot.fillColor = t.color(1 + i % 3).withAlpha(0.95)
            t.root.addSublayer(blot)

            let delay = min(0.65, rng.double(0, 0.5))
            t.add(blot, "transform",
                  covered: nv(Geo.transform(scale: 1.0, rotate: 0)),
                  open: nv(Geo.transform(scale: 0.0, rotate: rng.cg(-0.8, 0.8))),
                  begin: delay, span: max(0.35, 1 - delay), curve: .emphasized)
        }
    }
}

// MARK: - 18. Slide

/// The plainest one — a sheet leaving with a little parallax.
struct SlideTransition: Transition {
    let id = "slide"
    let title = "Slide"
    let blurb = "A single sheet leaves upward with parallax."
    var baseDuration: CFTimeInterval { 0.8 }

    func build(_ t: Timeline) {
        let sheet = t.group(t.bounds)
        sheet.masksToBounds = true
        _ = t.gradient(t.bounds, [t.color(1), t.color(0)],
                       from: CGPoint(x: 0.5, y: 0), to: CGPoint(x: 0.5, y: 1), parent: sheet)

        let shine = t.gradient(CGRect(x: 0, y: t.h * 0.2, width: t.w, height: t.h * 0.6),
                               [t.color(3).withAlpha(0), t.color(3).withAlpha(0.28), t.color(3).withAlpha(0)],
                               from: CGPoint(x: 0, y: 0.5), to: CGPoint(x: 1, y: 0.5), parent: sheet)
        t.add(shine, "transform",
              covered: nv(Geo.transform(translate: CGPoint(x: -t.w * 0.5, y: 0))),
              open: nv(Geo.transform(translate: CGPoint(x: t.w * 0.5, y: 0))),
              curve: .standard)

        _ = t.gradient(CGRect(x: 0, y: t.h - 90, width: t.w, height: 90),
                       [NSColor.black.withAlphaComponent(0).cgColor, NSColor.black.withAlphaComponent(0.18).cgColor],
                       from: CGPoint(x: 0.5, y: 0), to: CGPoint(x: 0.5, y: 1), parent: sheet)

        t.add(sheet, "transform",
              covered: nv(CATransform3DIdentity),
              open: nv(Geo.transform(translate: CGPoint(x: 0, y: -t.h * 1.04), scale: 0.94)),
              curve: .anticipate)
    }
}

// MARK: - 19. Bars

/// Vertical bars springing down from the top edge, centre outward.
struct BarsTransition: Transition {
    let id = "bars"
    let title = "Bars"
    let blurb = "Vertical bars spring away, centre outward."
    var baseDuration: CFTimeInterval { 0.95 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.color(1), t.color(0)], at: 0.8)
        let count = 18
        let bw = t.w / CGFloat(count)
        let mid = Double(count - 1) / 2

        for i in 0..<count {
            let x = CGFloat(i) * bw
            let bar = t.gradient(CGRect(x: x, y: 0, width: bw + 1.2, height: t.h),
                                 [t.color(1 + i % 3), t.color(0)],
                                 from: CGPoint(x: 0.5, y: 0), to: CGPoint(x: 0.5, y: 1))
            bar.anchorPoint = CGPoint(x: 0.5, y: 0)
            bar.position = CGPoint(x: x + bw / 2, y: 0)

            let delay = min(0.55, abs(Double(i) - mid) / mid * 0.45)
            t.add(bar, "transform",
                  covered: nv(CATransform3DIdentity),
                  open: nv(CATransform3DMakeScale(1, 0.001, 1)),
                  begin: delay, span: max(0.4, 1 - delay), curve: .snappy)
        }
    }
}

// MARK: - 20. Spiral

/// A radar sweep that unwinds around the centre.
struct SpiralTransition: Transition {
    let id = "spiral"
    let title = "Spiral"
    let blurb = "A radar sweep unwinds around the centre."
    var baseDuration: CFTimeInterval { 1.1 }

    func build(_ t: Timeline) {
        let wash = t.backdrop([t.color(1), t.color(2), t.color(0)])
        let r = t.diagonal * 0.62
        let start = -CGFloat.pi / 2

        let mask = CAShapeLayer()
        mask.frame = t.bounds
        mask.fillColor = NSColor.black.cgColor
        wash.mask = mask

        let steps = 24
        var paths: [CGPath] = []
        for i in 0...steps {
            let f = CGFloat(i) / CGFloat(steps)          // 0 = covered (full circle), 1 = open (nothing)
            let sweep = (1 - f) * .pi * 2
            paths.append(Geo.wedge(center: t.center, radius: r, start: start, sweep: sweep, samples: 96))
        }
        t.addPathKeyframe(mask, values: paths, curve: .linear)

        // The leading edge of the sweep, as a rotating spoke.
        let spoke = t.gradient(CGRect(x: 0, y: 0, width: r, height: 5),
                               [t.color(3).withAlpha(0.95), t.color(3).withAlpha(0)],
                               from: CGPoint(x: 0, y: 0.5), to: CGPoint(x: 1, y: 0.5))
        spoke.anchorPoint = CGPoint(x: 0, y: 0.5)
        spoke.position = t.center
        t.add(spoke, "transform",
              covered: nv(CATransform3DMakeRotation(start + .pi * 2, 0, 0, 1)),
              open: nv(CATransform3DMakeRotation(start, 0, 0, 1)),
              curve: .standard)
        t.addKeyframe(spoke, "opacity", values: [Float(0), Float(0.9), Float(0)], curve: .linear)
    }
}
