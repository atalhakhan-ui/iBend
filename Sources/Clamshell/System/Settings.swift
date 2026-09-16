import Foundation
import Combine

/// Everything the user can tune, persisted in `UserDefaults`.
final class Settings: ObservableObject {
    static let shared = Settings()

    private let d = UserDefaults.standard

    @Published var enabled: Bool { didSet { d.set(enabled, forKey: "enabled") } }
    @Published var openingID: String { didSet { d.set(openingID, forKey: "openingID") } }
    @Published var closingID: String { didSet { d.set(closingID, forKey: "closingID") } }
    @Published var paletteID: String { didSet { d.set(paletteID, forKey: "paletteID") } }
    @Published var speed: Double { didSet { d.set(speed, forKey: "speed") } }
    @Published var playOnLid: Bool { didSet { d.set(playOnLid, forKey: "playOnLid") } }
    @Published var playOnSleepWake: Bool { didSet { d.set(playOnSleepWake, forKey: "playOnSleepWake") } }
    @Published var playOnLock: Bool { didSet { d.set(playOnLock, forKey: "playOnLock") } }
    @Published var allScreens: Bool { didSet { d.set(allScreens, forKey: "allScreens") } }

    private init() {
        d.register(defaults: [
            "enabled": true,
            "openingID": "duoblur",
            "closingID": "duoblur",
            "paletteID": "duo",
            "speed": 1.0,
            "playOnLid": true,
            "playOnSleepWake": true,
            "playOnLock": false,
            "allScreens": true
        ])
        enabled = d.bool(forKey: "enabled")
        openingID = d.string(forKey: "openingID") ?? "duoblur"
        closingID = d.string(forKey: "closingID") ?? "duoblur"
        paletteID = d.string(forKey: "paletteID") ?? "duo"
        speed = d.double(forKey: "speed")
        playOnLid = d.bool(forKey: "playOnLid")
        playOnSleepWake = d.bool(forKey: "playOnSleepWake")
        playOnLock = d.bool(forKey: "playOnLock")
        allScreens = d.bool(forKey: "allScreens")
        if speed <= 0 { speed = 1.0 }
    }

    var palette: Palette { Palette.named(paletteID) }

    /// Speed is expressed as a multiplier the user drags; duration divides by it.
    func duration(for transition: Transition) -> CFTimeInterval {
        max(0.25, transition.baseDuration / max(0.35, speed))
    }
}
