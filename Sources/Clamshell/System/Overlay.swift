import AppKit
import QuartzCore

/// A layer-backed canvas that hosts one transition's layer tree at a time.
final class TransitionHostView: NSView {
    private var current: CALayer?
    private var backdrop: NSView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layerContentsRedrawPolicy = .never
    }

    required init?(coder: NSCoder) { fatalError() }

    func present(_ newLayer: CALayer, backdrop newBackdrop: NSView? = nil) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        current?.removeFromSuperlayer()
        backdrop?.removeFromSuperview()
        backdrop = nil

        // The backdrop is a real subview and must sit beneath the layer tree, so it is
        // added first and the transition's layers composite on top of it.
        if let newBackdrop {
            newBackdrop.frame = bounds
            newBackdrop.autoresizingMask = [.width, .height]
            addSubview(newBackdrop)
            backdrop = newBackdrop
        }

        newLayer.frame = bounds
        layer?.addSublayer(newLayer)
        current = newLayer
        CATransaction.commit()
    }

    func clear() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        current?.removeFromSuperlayer()
        current = nil
        backdrop?.removeFromSuperview()
        backdrop = nil
        CATransaction.commit()
    }

    var hasContent: Bool { current != nil }
}

/// A borderless, click-through window pinned above everything on one screen.
final class OverlayWindow: NSWindow {
    let host: TransitionHostView

    init(screen: NSScreen) {
        host = TransitionHostView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        displaysWhenScreenProfileChanges = true
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        contentView = host
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
