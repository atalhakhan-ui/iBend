import AppKit
import SwiftUI
import QuartzCore

/// A small, self-looping instance of a transition: close, beat, open, beat, repeat.
/// It drives the exact same renderer the full-screen overlay uses, so what you pick
/// in the gallery is what you get on the lid.
final class LoopingPreviewView: NSView {
    private var transition: Transition = TransitionLibrary.all[0]
    private var palette: Palette = Palette.all[0]
    private var duration: CFTimeInterval = 0.9
    private var timer: Timer?
    private var showingCovered = false
    private var host: TransitionHostView!
    private var desktopWash: CAGradientLayer?
    private var desktopCards: [CALayer] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.14, alpha: 1).cgColor
        layer.map(makeDesktopStandIn)
        host = TransitionHostView(frame: bounds)
        host.autoresizingMask = [.width, .height]
        addSubview(host)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(transition: Transition, palette: Palette, duration: CFTimeInterval) {
        let changed = transition.id != self.transition.id
            || palette != self.palette
            || duration != self.duration
        self.transition = transition
        self.palette = palette
        self.duration = duration
        if changed && timer != nil { restart() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { restart() } else { stop() }
    }

    override func layout() {
        super.layout()
        host.frame = bounds
        layoutDesktopStandIn()
    }

    /// Something for the transition to cover — and, for the blur transitions, something
    /// for the frost to actually act on. A tile over flat black tells you nothing.
    private static let desktopCards: [CGRect] = [
        CGRect(x: 0.08, y: 0.18, width: 0.46, height: 0.50),
        CGRect(x: 0.40, y: 0.44, width: 0.52, height: 0.46)
    ]

    private func makeDesktopStandIn(_ parent: CALayer) {
        let wash = CAGradientLayer()
        wash.colors = [
            NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.30, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.28, green: 0.16, blue: 0.32, alpha: 1).cgColor
        ]
        wash.startPoint = CGPoint(x: 0, y: 0)
        wash.endPoint = CGPoint(x: 1, y: 1)
        parent.addSublayer(wash)

        // A couple of suggested windows, so blur and coverage are legible at a glance.
        var cards: [CALayer] = []
        for _ in Self.desktopCards {
            let card = CALayer()
            card.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
            card.cornerRadius = 6
            card.borderWidth = 1
            card.borderColor = NSColor.white.withAlphaComponent(0.22).cgColor
            parent.addSublayer(card)
            cards.append(card)
        }

        desktopWash = wash
        desktopCards = cards
        layoutDesktopStandIn()
    }

    private func layoutDesktopStandIn() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        desktopWash?.frame = bounds
        for (card, unit) in zip(desktopCards, Self.desktopCards) {
            card.frame = CGRect(x: bounds.width * unit.minX, y: bounds.height * unit.minY,
                                width: bounds.width * unit.width, height: bounds.height * unit.height)
        }
        CATransaction.commit()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        host.clear()
    }

    private func restart() {
        timer?.invalidate()
        showingCovered = false
        step()
        // Two animations plus a beat on each side.
        let cycle = (duration + 0.55) * 2
        timer = Timer.scheduledTimer(withTimeInterval: cycle / 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
    }

    private func step() {
        guard bounds.width > 4, bounds.height > 4 else { return }
        let direction: TransitionDirection = showingCovered ? .opening : .closing
        showingCovered.toggle()
        let ctx = TransitionContext(
            size: bounds.size,
            direction: direction,
            palette: palette,
            duration: duration,
            scale: window?.backingScaleFactor ?? 2,
            startTime: CACurrentMediaTime() + 0.02,
            isPreview: true
        )
        host.present(TransitionRenderer.makeLayer(transition, ctx: ctx),
                     backdrop: transition.makeBackdrop(ctx))
    }
}

struct TransitionPreview: NSViewRepresentable {
    let transition: Transition
    let palette: Palette
    let duration: CFTimeInterval

    func makeNSView(context: Context) -> LoopingPreviewView {
        let v = LoopingPreviewView(frame: .zero)
        v.configure(transition: transition, palette: palette, duration: duration)
        return v
    }

    func updateNSView(_ nsView: LoopingPreviewView, context: Context) {
        nsView.configure(transition: transition, palette: palette, duration: duration)
    }

    static func dismantleNSView(_ nsView: LoopingPreviewView, coordinator: ()) {
        nsView.stop()
    }
}
