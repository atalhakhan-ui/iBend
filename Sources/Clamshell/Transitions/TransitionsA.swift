import AppKit
import QuartzCore

// MARK: - 1. Duo

/// Two broad colour ribbons that sweep past each other and off opposite corners.
struct DuoTransition: Transition {
    let id = "duo"
    let title = "Duo"
    let blurb = "Two colour ribbons sweep past each other."
    var baseDuration: CFTimeInterval { 1.05 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.color(0), t.color(1)], at: 0.66)

        let rw = t.w * 2.0, rh = t.h * 0.88
        let specs: [(colors: [CGColor], y: CGFloat, out: CGPoint, rot: CGFloat, delay: Double)] = [
            ([t.color(1), t.color(2)], t.h * 0.28, CGPoint(x: -t.w * 0.95, y: -t.h * 0.60), -0.18, 0.00),
            ([t.color(2), t.color(3)], t.h * 0.74, CGPoint(x:  t.w * 1.95, y:  t.h * 1.60),  0.18, 0.12)
        ]

        for s in specs {
            let frame = CGRect(x: t.w / 2 - rw / 2, y: s.y - rh / 2, width: rw, height: rh)
            let g = t.gradient(frame, s.colors, from: CGPoint(x: 0, y: 0.15), to: CGPoint(x: 1, y: 0.85))
            g.cornerRadius = rh / 2
            g.masksToBounds = true

            t.add(g, "position",
                  covered: nv(CGPoint(x: t.w / 2, y: s.y)), open: nv(s.out),
                  begin: s.delay, span: 1 - s.delay, curve: .emphasized)
            t.add(g, "transform",
                  covered: nv(Geo.transform(scale: 1.0, rotate: s.rot)),
                  open: nv(Geo.transform(scale: 0.86, rotate: s.rot * 2.6)),
                  begin: s.delay, span: 1 - s.delay, curve: .gentle)
            t.add(g, "opacity", covered: Float(1), open: Float(0), begin: 0, span: 0.30, curve: .easeOut)
        }
    }
}

// MARK: - 2. Clamshell

/// The literal gesture: the screen splits along a hinge and the two halves part.
struct ClamshellTransition: Transition {
    let id = "clamshell"
    let title = "Clamshell"
    let blurb = "The screen hinges open along its middle."
    var baseDuration: CFTimeInterval { 1.0 }

    func build(_ t: Timeline) {
        let half = t.h / 2

        let top = t.gradient(CGRect(x: 0, y: 0, width: t.w, height: half),
                             [t.color(0), t.color(1)], from: CGPoint(x: 0.2, y: 0), to: CGPoint(x: 0.8, y: 1))
        let bottom = t.gradient(CGRect(x: 0, y: half, width: t.w, height: half),
                                [t.color(1), t.color(0)], from: CGPoint(x: 0.2, y: 0), to: CGPoint(x: 0.8, y: 1))

        t.add(top, "transform",
              covered: nv(CATransform3DIdentity),
              open: nv(Geo.transform(translate: CGPoint(x: 0, y: -half * 1.04), rotateX: 0.42, perspective: 1400)),
              curve: .anticipate)
        t.add(bottom, "transform",
              covered: nv(CATransform3DIdentity),
              open: nv(Geo.transform(translate: CGPoint(x: 0, y: half * 1.04), rotateX: -0.42, perspective: 1400)),
              curve: .anticipate)

        // Hinge flare along the seam.
        let seam = t.gradient(CGRect(x: 0, y: half - 1.5, width: t.w, height: 3),
                              [t.color(3).withAlpha(0), t.color(3), t.color(3).withAlpha(0)],
                              from: CGPoint(x: 0, y: 0.5), to: CGPoint(x: 1, y: 0.5))
        t.add(seam, "opacity", covered: Float(0.0), open: Float(0.95), begin: 0, span: 0.45, curve: .easeOut)
        t.add(seam, "transform",
              covered: nv(Geo.transform(scale: 0.4)), open: nv(Geo.transform(scale: 1.0)),
              begin: 0, span: 0.55, curve: .easeOut)
    }
}

// MARK: - 3. Iris

/// A single aperture opening from the centre, with a light ring riding its edge.
struct IrisTransition: Transition {
    let id = "iris"
    let title = "Iris"
    let blurb = "A circular aperture opens from the centre."
    var baseDuration: CFTimeInterval { 0.9 }

    func build(_ t: Timeline) {
        let wash = t.backdrop([t.color(1), t.color(0)])
        let maxR = t.diagonal * 0.62

        let mask = CAShapeLayer()
        mask.frame = t.bounds
        mask.fillRule = .evenOdd
        mask.fillColor = NSColor.black.cgColor
        wash.mask = mask
        t.addPath(mask,
                  covered: Geo.rectWithHole(t.bounds, center: t.center, radius: 0.001),
                  open: Geo.rectWithHole(t.bounds, center: t.center, radius: maxR),
                  curve: .emphasized)

        let ring = CAShapeLayer()
        ring.frame = t.bounds
        ring.fillColor = nil
        ring.strokeColor = t.color(3).withAlpha(0.9)
        ring.lineWidth = 3
        t.root.addSublayer(ring)
        t.addPath(ring,
                  covered: ellipse(t.center, 0.001),
                  open: ellipse(t.center, maxR),
                  curve: .emphasized)
        t.add(ring, "opacity", covered: Float(0), open: Float(0), begin: 0, span: 1, curve: .linear)
        t.addKeyframe(ring, "opacity", values: [Float(0), Float(0.9), Float(0.5), Float(0)], curve: .linear)

        let core = t.glow(center: t.center, radius: t.w * 0.22, color: t.color(3), softness: 1.1)
        t.add(core, "opacity", covered: Float(0.5), open: Float(0), begin: 0, span: 0.5, curve: .easeOut)
    }

    private func ellipse(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil)
    }
}

// MARK: - 4. Shutter

/// Camera-shutter blades rotating away from the centre.
struct ShutterTransition: Transition {
    let id = "shutter"
    let title = "Shutter"
    let blurb = "Camera blades rotate away from the centre."
    var baseDuration: CFTimeInterval { 0.95 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.color(0), t.color(1)], at: 0.78)

        let blades = 9
        let r = t.diagonal * 0.62
        let sweep = CGFloat.pi * 2 / CGFloat(blades) * 1.08

        for i in 0..<blades {
            let start = CGFloat(i) / CGFloat(blades) * .pi * 2 - .pi / 2
            let path = Geo.wedge(center: t.center, radius: r, start: start, sweep: sweep, samples: 24)
            let blade = t.shape(path, fill: t.color(1 + i % 3).withAlpha(0.98))
            blade.anchorPoint = CGPoint(x: t.center.x / t.w, y: t.center.y / t.h)
            blade.frame = t.bounds
            blade.position = t.center

            let delay = 0.045 * Double(i)
            t.add(blade, "transform",
                  covered: nv(CATransform3DIdentity),
                  open: nv(Geo.transform(scale: 1.4, rotate: -0.9)),
                  begin: delay, span: 1 - delay, curve: .emphasized)
            t.add(blade, "opacity", covered: Float(1), open: Float(0),
                  begin: delay, span: 0.45, curve: .easeOut)
        }
    }
}

// MARK: - 5. Aurora

/// Slow drifting light fields — the quietest one in the set.
struct AuroraTransition: Transition {
    let id = "aurora"
    let title = "Aurora"
    let blurb = "Soft light fields drift apart and dissolve."
    var baseDuration: CFTimeInterval { 1.35 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.color(0), t.color(0)], at: 0.55)

        var rng = SeededRNG(0xA0A0)
        for i in 0..<6 {
            let radius = t.w * rng.cg(0.34, 0.62)
            let cx = t.w * rng.cg(0.12, 0.88)
            let cy = t.h * rng.cg(0.10, 0.90)
            let g = t.glow(center: CGPoint(x: cx, y: cy), radius: radius, color: t.color(i + 1), softness: 1.0)
            g.opacity = 0.9

            let outward = CGPoint(x: cx + (cx - t.w / 2) * 1.5, y: cy + (cy - t.h / 2) * 1.5)
            let delay = 0.06 * Double(i)
            t.add(g, "position",
                  covered: nv(CGPoint(x: cx, y: cy)), open: nv(outward),
                  begin: delay, span: 1 - delay, curve: .gentle)
            t.add(g, "transform",
                  covered: nv(Geo.transform(scale: 1.0)), open: nv(Geo.transform(scale: 1.7)),
                  begin: delay, span: 1 - delay, curve: .gentle)
            t.add(g, "opacity", covered: Float(0.9), open: Float(0),
                  begin: delay * 0.5, span: 0.55, curve: .easeOut)
        }
    }
}

// MARK: - 6. Liquid

/// An organic blob that pulls itself inward to a point.
struct LiquidTransition: Transition {
    let id = "liquid"
    let title = "Liquid"
    let blurb = "An organic blob draws itself inward."
    var baseDuration: CFTimeInterval { 1.1 }

    func build(_ t: Timeline) {
        let wash = t.backdrop([t.color(1), t.color(2), t.color(0)])
        let mask = CAShapeLayer()
        mask.frame = t.bounds
        mask.fillColor = NSColor.black.cgColor
        wash.mask = mask

        let maxR = t.diagonal * 0.62
        let steps = 7
        var paths: [CGPath] = []
        for i in 0...steps {
            let f = CGFloat(i) / CGFloat(steps)              // 0 = covered, 1 = open
            let r = maxR * pow(1 - f, 1.35)
            let wobble = 0.035 + f * 0.40
            paths.append(Geo.blob(center: t.center, radius: r, wobble: wobble, phase: f * 3.4, lobes: 5))
        }
        t.addPathKeyframe(mask, values: paths, curve: .emphasized)

        // A trailing droplet that lags behind the main body.
        let drop = t.gradient(t.bounds, [t.color(3), t.color(2)])
        let dropMask = CAShapeLayer()
        dropMask.frame = t.bounds
        dropMask.fillColor = NSColor.black.cgColor
        drop.mask = dropMask
        let dc = CGPoint(x: t.w * 0.62, y: t.h * 0.38)
        var dropPaths: [CGPath] = []
        for i in 0...steps {
            let f = CGFloat(i) / CGFloat(steps)
            let r = t.w * 0.22 * pow(sin(.pi * f), 1.2)
            dropPaths.append(Geo.blob(center: dc, radius: r, wobble: 0.08 + f * 0.3, phase: 1.2 + f * 2, lobes: 4))
        }
        t.addPathKeyframe(dropMask, values: dropPaths, begin: 0.12, span: 0.7, curve: .emphasized)
    }
}

// MARK: - 7. Venetian

/// Horizontal slats collapsing to their own centre lines.
struct VenetianTransition: Transition {
    let id = "venetian"
    let title = "Venetian"
    let blurb = "Horizontal slats tilt and collapse."
    var baseDuration: CFTimeInterval { 0.95 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.ramp(0.2), t.ramp(0.8)], at: 0.75)
        let count = 16
        let slatH = t.h / CGFloat(count)

        for i in 0..<count {
            let y = CGFloat(i) * slatH
            let band = Double(i) / Double(count)
            let g = t.gradient(CGRect(x: -2, y: y, width: t.w + 4, height: slatH + 1.5),
                               [t.ramp(band * 0.8 + 0.1), t.ramp(band * 0.8 + 0.28)],
                               from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 1))

            let delay = 0.035 * Double(i)
            t.add(g, "transform",
                  covered: nv(CATransform3DIdentity),
                  open: nv({
                      var m = CATransform3DIdentity
                      m.m34 = -1 / 900
                      m = CATransform3DRotate(m, 1.15, 1, 0, 0)
                      return CATransform3DScale(m, 1, 0.02, 1)
                  }()),
                  begin: delay, span: max(0.35, 1 - delay), curve: .emphasized)
            t.add(g, "opacity", covered: Float(1), open: Float(0),
                  begin: delay, span: 0.35, curve: .easeOut)
        }
    }
}

// MARK: - 8. Mosaic

/// A tile grid that scatters outward from the centre.
struct MosaicTransition: Transition {
    let id = "mosaic"
    let title = "Mosaic"
    let blurb = "A grid of tiles scatters from the centre."
    var baseDuration: CFTimeInterval { 1.0 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.ramp(0.15), t.ramp(0.85)], at: 0.78)
        let cols = 14
        let rows = max(6, Int((CGFloat(cols) * t.h / t.w).rounded()))
        let tw = t.w / CGFloat(cols), th = t.h / CGFloat(rows)
        var rng = SeededRNG(0x5EED)
        let maxDist = hypot(CGFloat(cols) / 2, CGFloat(rows) / 2)

        for r in 0..<rows {
            for c in 0..<cols {
                let rect = CGRect(x: CGFloat(c) * tw, y: CGFloat(r) * th, width: tw + 1.2, height: th + 1.2)
                let nx = (CGFloat(c) + 0.5) / CGFloat(cols)
                let ny = (CGFloat(r) + 0.5) / CGFloat(rows)
                let tint = t.ramp(Double(nx * 0.55 + ny * 0.45)).withAlpha(0.95 + 0.05 * rng.cg())
                let tile = t.solid(rect, tint)

                let dist = hypot(CGFloat(c) - CGFloat(cols - 1) / 2, CGFloat(r) - CGFloat(rows - 1) / 2) / maxDist
                let delay = min(0.62, Double(dist) * 0.5 + rng.double(0, 0.08))
                let spin = rng.cg(-0.7, 0.7)
                t.add(tile, "transform",
                      covered: nv(CATransform3DIdentity),
                      open: nv(Geo.transform(scale: 0.02, rotate: spin)),
                      begin: delay, span: max(0.3, 1 - delay), curve: .emphasized)
                t.add(tile, "opacity", covered: Float(1), open: Float(0),
                      begin: delay, span: 0.28, curve: .easeOut)
            }
        }
    }
}

// MARK: - 9. Hex

/// Honeycomb cells retreating in a radial wave.
struct HexTransition: Transition {
    let id = "hex"
    let title = "Hex"
    let blurb = "Honeycomb cells retreat in a radial wave."
    var baseDuration: CFTimeInterval { 1.0 }

    func build(_ t: Timeline) {
        t.sealBackdrop([t.color(1), t.color(2)], at: 0.86)
        let r = t.w / 15
        let stepX = r * 1.5
        let stepY = r * sqrt(3)
        let cols = Int(ceil(t.w / stepX)) + 2
        let rows = Int(ceil(t.h / stepY)) + 2
        let maxDist = t.diagonal / 2

        for c in 0..<cols {
            for row in 0..<rows {
                let x = CGFloat(c) * stepX - stepX / 2
                let y = CGFloat(row) * stepY - stepY / 2 + (c % 2 == 0 ? 0 : stepY / 2)
                let cell = CAShapeLayer()
                cell.bounds = CGRect(x: 0, y: 0, width: r * 2.2, height: r * 2.2)
                cell.position = CGPoint(x: x, y: y)
                cell.path = Geo.hexagon(center: CGPoint(x: r * 1.1, y: r * 1.1), radius: r * 1.02)
                cell.fillColor = t.color((c + row) % 3 + 1).withAlpha(0.96)
                t.root.addSublayer(cell)

                let dist = hypot(x - t.w / 2, y - t.h / 2) / maxDist
                let delay = min(0.6, Double(dist) * 0.55)
                t.add(cell, "transform",
                      covered: nv(CATransform3DIdentity),
                      open: nv(Geo.transform(scale: 0.0, rotate: 0.5)),
                      begin: delay, span: max(0.3, 1 - delay), curve: .emphasized)
            }
        }
    }
}

// MARK: - 10. Curtain

/// Two panels parting, with a seam of light between them.
struct CurtainTransition: Transition {
    let id = "curtain"
    let title = "Curtain"
    let blurb = "Two panels part, trailing a seam of light."
    var baseDuration: CFTimeInterval { 0.9 }

    func build(_ t: Timeline) {
        let half = t.w / 2

        for side in [-1.0, 1.0] as [CGFloat] {
            let x = side < 0 ? 0 : half
            let panel = t.group(CGRect(x: x, y: 0, width: half, height: t.h))
            panel.masksToBounds = true
            _ = t.gradient(CGRect(x: 0, y: 0, width: half, height: t.h),
                           [t.color(1), t.color(0)],
                           from: CGPoint(x: side < 0 ? 0 : 1, y: 0),
                           to: CGPoint(x: side < 0 ? 1 : 0, y: 1),
                           parent: panel)
            // Inner edge shade, so the two panels read as separate sheets.
            let edgeW: CGFloat = 60
            _ = t.gradient(CGRect(x: side < 0 ? half - edgeW : 0, y: 0, width: edgeW, height: t.h),
                           side < 0
                             ? [NSColor.black.withAlphaComponent(0).cgColor, NSColor.black.withAlphaComponent(0.20).cgColor]
                             : [NSColor.black.withAlphaComponent(0.20).cgColor, NSColor.black.withAlphaComponent(0).cgColor],
                           from: CGPoint(x: 0, y: 0.5), to: CGPoint(x: 1, y: 0.5),
                           parent: panel)

            t.add(panel, "transform",
                  covered: nv(CATransform3DIdentity),
                  open: nv(Geo.transform(translate: CGPoint(x: side * half * 1.02, y: 0), scale: 1.04)),
                  curve: .emphasized)
        }

        let seam = t.gradient(CGRect(x: half - 40, y: 0, width: 80, height: t.h),
                              [t.color(3).withAlpha(0), t.color(3).withAlpha(0.85), t.color(3).withAlpha(0)],
                              from: CGPoint(x: 0, y: 0.5), to: CGPoint(x: 1, y: 0.5))
        t.addKeyframe(seam, "opacity", values: [Float(0.22), Float(0.95), Float(0)], curve: .linear)
    }
}
