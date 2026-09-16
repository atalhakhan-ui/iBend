import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let settings = Settings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "laptopcomputer",
                                           accessibilityDescription: "iBend")
        statusItem.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        LidMonitor.shared.start()

        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            GalleryWindowController.shared.show()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(item("Preview Opening", #selector(previewOpening)))
        menu.addItem(item("Preview Closing", #selector(previewClosing)))
        menu.addItem(item("Preview Both", #selector(previewBoth)))
        menu.addItem(.separator())

        menu.addItem(transitionSubmenu(title: "When the lid opens", slot: .opening))
        menu.addItem(transitionSubmenu(title: "When the lid closes", slot: .closing))
        menu.addItem(paletteSubmenu())
        menu.addItem(speedSubmenu())
        menu.addItem(.separator())

        menu.addItem(item("Transitions…", #selector(openGallery)))
        menu.addItem(.separator())

        let enabled = item("Enabled", #selector(toggleEnabled))
        enabled.state = settings.enabled ? .on : .off
        menu.addItem(enabled)
        menu.addItem(triggersSubmenu())

        let login = item("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        menu.addItem(item("Hide Overlay Now", #selector(hideOverlay)))
        menu.addItem(item("Quit iBend", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    private func transitionSubmenu(title: String, slot: Slot) -> NSMenuItem {
        let current = slot == .opening ? settings.openingID : settings.closingID
        let parent = NSMenuItem(title: "\(title): \(TransitionLibrary.title(for: current))",
                                action: nil, keyEquivalent: "")
        let sub = NSMenu()

        let random = NSMenuItem(title: "Random",
                                action: slot == .opening ? #selector(pickOpening(_:)) : #selector(pickClosing(_:)),
                                keyEquivalent: "")
        random.target = self
        random.representedObject = TransitionLibrary.randomID
        random.state = current == TransitionLibrary.randomID ? .on : .off
        sub.addItem(random)
        sub.addItem(.separator())

        for t in TransitionLibrary.all {
            let i = NSMenuItem(title: t.title,
                               action: slot == .opening ? #selector(pickOpening(_:)) : #selector(pickClosing(_:)),
                               keyEquivalent: "")
            i.target = self
            i.representedObject = t.id
            i.state = current == t.id ? .on : .off
            sub.addItem(i)
        }
        parent.submenu = sub
        return parent
    }

    private func paletteSubmenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Palette: \(settings.palette.name)", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for p in Palette.all {
            let i = NSMenuItem(title: p.name, action: #selector(pickPalette(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = p.id
            i.state = settings.paletteID == p.id ? .on : .off
            sub.addItem(i)
        }
        parent.submenu = sub
        return parent
    }

    private func speedSubmenu() -> NSMenuItem {
        let parent = NSMenuItem(title: String(format: "Speed: %.2f×", settings.speed),
                                action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for v in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0] {
            let i = NSMenuItem(title: String(format: "%.2f×", v), action: #selector(pickSpeed(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = v
            i.state = abs(settings.speed - v) < 0.01 ? .on : .off
            sub.addItem(i)
        }
        parent.submenu = sub
        return parent
    }

    private func triggersSubmenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Triggers", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let entries: [(String, Bool, Selector)] = [
            ("Lid open / close", settings.playOnLid, #selector(toggleLid)),
            ("Sleep / wake", settings.playOnSleepWake, #selector(toggleSleepWake)),
            ("Screen lock / unlock", settings.playOnLock, #selector(toggleLock)),
            ("Play on all displays", settings.allScreens, #selector(toggleAllScreens))
        ]
        for (title, on, sel) in entries {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            i.target = self
            i.state = on ? .on : .off
            sub.addItem(i)
        }
        parent.submenu = sub
        return parent
    }

    // MARK: Actions

    @objc private func previewOpening() { TransitionController.shared.play(.opening) }
    @objc private func previewClosing() { TransitionController.shared.play(.closing) }
    @objc private func previewBoth() { TransitionController.shared.previewRoundTrip(nil, nil) }
    @objc private func openGallery() { GalleryWindowController.shared.show() }
    @objc private func hideOverlay() { TransitionController.shared.hide() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func pickOpening(_ sender: NSMenuItem) {
        settings.openingID = sender.representedObject as? String ?? settings.openingID
    }

    @objc private func pickClosing(_ sender: NSMenuItem) {
        settings.closingID = sender.representedObject as? String ?? settings.closingID
    }

    @objc private func pickPalette(_ sender: NSMenuItem) {
        settings.paletteID = sender.representedObject as? String ?? settings.paletteID
    }

    @objc private func pickSpeed(_ sender: NSMenuItem) {
        settings.speed = sender.representedObject as? Double ?? settings.speed
    }

    @objc private func toggleEnabled() { settings.enabled.toggle() }
    @objc private func toggleLid() { settings.playOnLid.toggle() }
    @objc private func toggleSleepWake() { settings.playOnSleepWake.toggle() }
    @objc private func toggleLock() { settings.playOnLock.toggle() }
    @objc private func toggleAllScreens() { settings.allScreens.toggle() }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("iBend: launch-at-login change failed: \(error.localizedDescription)")
        }
    }
}
