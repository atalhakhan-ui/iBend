import AppKit
import QuartzCore

/// Real backdrop blur over whatever is actually on screen.
///
/// A CALayer cannot blur content behind its own window, so this is the one place the
/// project reaches for views. Two mechanisms stack:
///
/// * `backgroundFilters` with a `CIGaussianBlur` gives an **animatable radius** — the
///   progressive part, the thing that makes the frost arrive rather than appear.
/// * `NSVisualEffectView` is the guaranteed backdrop blur on macOS, faded in underneath
///   as a floor, so the transition still reads if Core Image filters are unavailable
///   (they depend on the window being non-opaque, which the overlay is).
///
/// Both are driven through the ordinary `Timeline`, so the close and the open reverse
/// themselves exactly like every other transition.
final class BlurBackdropView: NSView {

    init(ctx: TransitionContext, maxRadius: CGFloat, frostFloor: Float) {
        super.init(frame: CGRect(origin: .zero, size: ctx.size))
        wantsLayer = true
        // Required before a layer will honour Core Image filters at all.
        layerUsesCoreImageFilters = true
        guard let root = layer else { return }
        root.masksToBounds = true
        root.backgroundColor = NSColor.clear.cgColor

        let blur = CALayer()
        blur.frame = bounds
        blur.masksToBounds = true
        blur.backgroundColor = NSColor.clear.cgColor
        if let filter = CIFilter(name: "CIGaussianBlur") {
            filter.setValue(0, forKey: kCIInputRadiusKey)
            filter.name = "blur"          // names the keypath the animation drives
            blur.backgroundFilters = [filter]
        }
        root.addSublayer(blur)

        let frost = NSVisualEffectView(frame: bounds)
        frost.autoresizingMask = [.width, .height]
        frost.material = .fullScreenUI
        // In a gallery tile there is no desktop behind the window to sample.
        frost.blendingMode = ctx.isPreview ? .withinWindow : .behindWindow
        frost.state = .active
        frost.wantsLayer = true
        addSubview(frost)

        let t = Timeline(ctx: ctx, root: root)
        t.add(blur, "backgroundFilters.blur.inputRadius",
              covered: maxRadius, open: CGFloat(0), curve: .standard)
        if let frostLayer = frost.layer {
            t.add(frostLayer, "opacity",
                  covered: frostFloor, open: Float(0), begin: 0, span: 0.88, curve: .standard)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // The overlay is click-through; nothing here should ever take a hit.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - Duo Blur

/// The whole screen frosts over and resolves. No shapes, no wipe — the blur is the
/// transition, with only a breath of palette so it does not read as plain grey.
struct DuoBlurTransition: Transition {
    let id = "duoblur"
    let title = "Duo Blur"
    let blurb = "The screen frosts over and resolves, like a folding display."
    var baseDuration: CFTimeInterval { 0.8 }

    func build(_ t: Timeline) {
        // Deliberately not sealed to opaque: this transition is about seeing the desktop
        // go soft, so full coverage is heavy frost plus a light tint rather than a wall.
        let wash = t.backdrop([t.color(1).withAlpha(0.20), t.color(0).withAlpha(0.34)])
        t.add(wash, "opacity", covered: Float(1), open: Float(0), begin: 0, span: 0.9, curve: .standard)
        t.add(wash, "transform",
              covered: nv(Geo.transform(scale: 1.025)), open: nv(CATransform3DIdentity),
              curve: .standard)

        let bloom = t.glow(center: t.center, radius: t.w * 0.45, color: t.color(3), softness: 1.25)
        t.add(bloom, "opacity", covered: Float(0.22), open: Float(0), begin: 0, span: 0.72, curve: .easeOut)
    }

    func makeBackdrop(_ ctx: TransitionContext) -> NSView? {
        BlurBackdropView(ctx: ctx, maxRadius: 48, frostFloor: 1.0)
    }
}

// MARK: - Fold Frost

/// The same blur, but the frost arrives as two panels hinging shut down the middle —
/// the folding-display reading of the same idea.
struct FoldFrostTransition: Transition {
    let id = "foldfrost"
    let title = "Fold Frost"
    let blurb = "Frosted halves hinge shut down the middle."
    var baseDuration: CFTimeInterval { 0.95 }

    func build(_ t: Timeline) {
        let half = t.h / 2

        for side in [-1.0, 1.0] as [CGFloat] {
            let y = side < 0 ? 0 : half
            let panel = t.gradient(CGRect(x: 0, y: y, width: t.w, height: half),
                                   [t.color(1).withAlpha(0.30), t.color(0).withAlpha(0.42)],
                                   from: CGPoint(x: 0.2, y: side < 0 ? 0 : 1),
                                   to: CGPoint(x: 0.8, y: side < 0 ? 1 : 0))
            t.add(panel, "transform",
                  covered: nv(CATransform3DIdentity),
                  open: nv(Geo.transform(translate: CGPoint(x: 0, y: side * half * 1.04),
                                         rotateX: -side * 0.38, perspective: 1500)),
                  curve: .gentle)
        }

        let seam = t.gradient(CGRect(x: 0, y: half - 1.5, width: t.w, height: 3),
                              [t.color(3).withAlpha(0), t.color(3).withAlpha(0.85), t.color(3).withAlpha(0)],
                              from: CGPoint(x: 0, y: 0.5), to: CGPoint(x: 1, y: 0.5))
        t.addKeyframe(seam, "opacity", values: [Float(0.3), Float(0.9), Float(0)], curve: .linear)
    }

    func makeBackdrop(_ ctx: TransitionContext) -> NSView? {
        BlurBackdropView(ctx: ctx, maxRadius: 36, frostFloor: 0.92)
    }
}
