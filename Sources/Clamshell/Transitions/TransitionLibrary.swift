import Foundation

enum TransitionLibrary {
    static let all: [Transition] = [
        DuoTransition(),
        ClamshellTransition(),
        IrisTransition(),
        ShutterTransition(),
        AuroraTransition(),
        LiquidTransition(),
        VenetianTransition(),
        MosaicTransition(),
        HexTransition(),
        CurtainTransition(),
        RippleTransition(),
        WarpTransition(),
        FoldTransition(),
        GlimmerTransition(),
        DissolveTransition(),
        HaloTransition(),
        InkTransition(),
        SlideTransition(),
        BarsTransition(),
        SpiralTransition()
    ]

    static let randomID = "random"

    static func transition(for id: String) -> Transition {
        if id == randomID { return all.randomElement() ?? all[0] }
        return all.first { $0.id == id } ?? all[0]
    }

    static func title(for id: String) -> String {
        id == randomID ? "Random" : (all.first { $0.id == id }?.title ?? all[0].title)
    }
}
