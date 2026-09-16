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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
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
            startTime: CACurrentMediaTime() + 0.02
        )
        host.present(TransitionRenderer.makeLayer(transition, ctx: ctx))
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
