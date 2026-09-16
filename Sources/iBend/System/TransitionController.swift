import AppKit
import QuartzCore

/// Owns the overlay windows and decides what plays, where, and for how long.
///
/// The covered state is sticky on purpose: when the lid goes down the overlay stays
/// opaque so that waking up can start from a covered screen and animate outward. A
/// watchdog exists because an overlay stuck at full coverage would be indistinguishable
/// from a hung machine.
@MainActor
final class TransitionController {
    static let shared = TransitionController()

    private var windows: [OverlayWindow] = []
    private var dismissWork: DispatchWorkItem?
    private var watchdog: Timer?

    private(set) var isCovered = false
    private(set) var isAsleep = false

    /// How long a close animation holds full coverage before giving the screen back,
    /// if the machine never actually slept (clamshell mode with an external display).
    private let coverHold: TimeInterval = 2.6
    /// Absolute ceiling on overlay visibility while awake.
    private let watchdogLimit: TimeInterval = 20

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildWindows() }
        }
    }

    // MARK: Windows

    private func targetScreens() -> [NSScreen] {
        Settings.shared.allScreens
            ? NSScreen.screens
            : [NSScreen.main].compactMap { $0 }
    }

    private func rebuildWindows() {
        let screens = targetScreens()
        guard windows.count != screens.count || !zip(windows, screens).allSatisfy({ $0.frame == $1.frame }) else { return }
        windows.forEach { $0.orderOut(nil) }
        windows = screens.map { OverlayWindow(screen: $0) }
    }

    private func ensureWindows() {
        let screens = targetScreens()
        if windows.count != screens.count {
            windows.forEach { $0.orderOut(nil) }
            windows = screens.map { OverlayWindow(screen: $0) }
        } else {
            for (w, s) in zip(windows, screens) where w.frame != s.frame {
                w.setFrame(s.frame, display: false)
                w.host.frame = NSRect(origin: .zero, size: s.frame.size)
            }
        }
    }

    // MARK: Playback

    func play(_ direction: TransitionDirection, transition explicit: Transition? = nil) {
        let settings = Settings.shared
        let id = direction == .opening ? settings.openingID : settings.closingID
        let transition = explicit ?? TransitionLibrary.transition(for: id)
        let duration = settings.duration(for: transition)

        dismissWork?.cancel()
        dismissWork = nil
        ensureWindows()

        let start = CACurrentMediaTime() + 0.03
        for window in windows {
            let size = window.frame.size
            let ctx = TransitionContext(
                size: size,
                direction: direction,
                palette: settings.palette,
                duration: duration,
                scale: window.screen?.backingScaleFactor ?? 2,
                startTime: start
            )
            window.host.present(TransitionRenderer.makeLayer(transition, ctx: ctx),
                                backdrop: transition.makeBackdrop(ctx))
            window.orderFrontRegardless()
        }

        isCovered = (direction == .closing)
        armWatchdog()

        switch direction {
        case .opening:
            schedule(after: duration + 0.08) { [weak self] in
                self?.hide()
            }
        case .closing:
            // Hold the cover; release it only if the machine never went to sleep.
            schedule(after: duration + coverHold) { [weak self] in
                guard let self, !self.isAsleep else { return }
                self.fadeOut()
            }
        }
    }

    /// Plays the closing transition, then the opening one — for previewing the round trip.
    func previewRoundTrip(_ transitionClosing: Transition?, _ transitionOpening: Transition?) {
        play(.closing, transition: transitionClosing)
        let closeDur = Settings.shared.duration(for: transitionClosing ?? TransitionLibrary.transition(for: Settings.shared.closingID))
        schedule(after: closeDur + 0.5) { [weak self] in
            self?.play(.opening, transition: transitionOpening)
        }
    }

    // MARK: Lifecycle signals

    func systemWillSleep() {
        isAsleep = true
        dismissWork?.cancel()
        watchdog?.invalidate()
    }

    func systemDidWake() {
        isAsleep = false
    }

    // MARK: Hiding

    func hide() {
        dismissWork?.cancel()
        dismissWork = nil
        watchdog?.invalidate()
        watchdog = nil
        isCovered = false
        for window in windows {
            window.orderOut(nil)
            window.host.clear()
            window.alphaValue = 1
        }
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.45
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            windows.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    private func schedule(after delay: TimeInterval, _ body: @escaping @MainActor () -> Void) {
        let work = DispatchWorkItem { MainActor.assumeIsolated(body) }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func armWatchdog() {
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: watchdogLimit, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isAsleep else { return }
                self.hide()
            }
        }
    }
}
