import AppKit

/// `NSApplication.delegate` is weak, so the delegate needs an owner that outlives launch.
@MainActor
enum Launcher {
    static var delegate: AppDelegate?

    static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        Launcher.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

// Debug entry points, for inspecting transitions without a display:
//   --contact-sheet <dir> [palette]   every transition, sampled across its timeline
//   --frame <id> <progress> <out.png> one transition at one moment
if let i = CommandLine.arguments.firstIndex(of: "--contact-sheet") {
    let dir = CommandLine.arguments.count > i + 1 ? CommandLine.arguments[i + 1] : "."
    let palette = CommandLine.arguments.count > i + 2 ? CommandLine.arguments[i + 2] : "duo"
    ContactSheet.run(outputDirectory: dir, paletteID: palette)
}

if let i = CommandLine.arguments.firstIndex(of: "--frame") {
    ContactSheet.single(CommandLine.arguments[i + 1],
                        progress: Double(CommandLine.arguments[i + 2]) ?? 0,
                        path: CommandLine.arguments[i + 3])
}

MainActor.assumeIsolated { Launcher.run() }
