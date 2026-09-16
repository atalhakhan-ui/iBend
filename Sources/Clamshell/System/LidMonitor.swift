import AppKit
import IOKit
import IOKit.pwr_mgt

/// Watches the things that mean "the lid moved": the clamshell bit in the IOKit power
/// registry, plus sleep/wake and lock/unlock as corroborating signals.
///
/// Several of these fire for a single physical gesture (closing the lid emits a clamshell
/// change *and* a sleep notification), so every trigger funnels through one debounced
/// request path rather than driving the controller directly.
@MainActor
final class LidMonitor {
    static let shared = LidMonitor()

    private var notifyPort: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private var rootDomain: io_service_t = 0
    private var lastClamshellClosed: Bool?
    private var lastPlayed: [ObjectIdentifier: Date] = [:]
    private var lastOpening = Date.distantPast
    private var lastClosing = Date.distantPast
    private let debounce: TimeInterval = 2.0

    private init() {}

    func start() {
        lastClamshellClosed = Self.clamshellClosed()
        startClamshellWatch()
        startWorkspaceWatch()
        startLockWatch()
    }

    // MARK: Clamshell

    static func clamshellClosed() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let raw = IORegistryEntryCreateCFProperty(
            service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() else { return nil }
        return (raw as? Bool) ?? ((raw as? NSNumber)?.boolValue)
    }

    private func startClamshellWatch() {
        rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != 0 else { return }

        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let port = notifyPort else { return }
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceInterestCallback = { refcon, _, _, _ in
            guard let refcon else { return }
            let monitor = Unmanaged<LidMonitor>.fromOpaque(refcon).takeUnretainedValue()
            // Any general-interest message is treated as "something power-related changed";
            // the registry read below is what actually decides whether the lid moved.
            MainActor.assumeIsolated { monitor.clamshellMayHaveChanged() }
        }
        IOServiceAddInterestNotification(port, rootDomain, kIOGeneralInterest, callback, context, &notifier)
    }

    private func clamshellMayHaveChanged() {
        guard let closed = Self.clamshellClosed() else { return }
        guard closed != lastClamshellClosed else { return }
        lastClamshellClosed = closed
        guard Settings.shared.playOnLid else { return }
        request(closed ? .closing : .opening)
    }

    // MARK: Sleep / wake

    private func startWorkspaceWatch() {
        let nc = NSWorkspace.shared.notificationCenter

        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                TransitionController.shared.systemWillSleep()
                guard let self, Settings.shared.playOnSleepWake else { return }
                self.request(.closing)
            }
        }
        nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { TransitionController.shared.systemWillSleep() }
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                TransitionController.shared.systemDidWake()
                self?.lastClamshellClosed = Self.clamshellClosed()
                guard let self, Settings.shared.playOnSleepWake else { return }
                self.request(.opening, delay: 0.25)
            }
        }
        nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                TransitionController.shared.systemDidWake()
                guard let self, Settings.shared.playOnSleepWake else { return }
                self.request(.opening, delay: 0.25)
            }
        }
    }

    private func startLockWatch() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, Settings.shared.playOnLock else { return }
                self.request(.closing)
            }
        }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, Settings.shared.playOnLock else { return }
                self.request(.opening)
            }
        }
    }

    // MARK: Debounced dispatch

    private func request(_ direction: TransitionDirection, delay: TimeInterval = 0) {
        guard Settings.shared.enabled else { return }
        let now = Date()
        switch direction {
        case .opening:
            guard now.timeIntervalSince(lastOpening) > debounce else { return }
            lastOpening = now
        case .closing:
            guard now.timeIntervalSince(lastClosing) > debounce else { return }
            lastClosing = now
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                MainActor.assumeIsolated { TransitionController.shared.play(direction) }
            }
        } else {
            TransitionController.shared.play(direction)
        }
    }
}
