import AppKit

struct Palette: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let hexes: [String]

    var colors: [CGColor] { hexes.map { Palette.color(fromHex: $0) } }
    var nsColors: [NSColor] { hexes.map { NSColor(cgColor: Palette.color(fromHex: $0)) ?? .black } }

    static func color(fromHex hex: String) -> CGColor {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = CGFloat((v >> 16) & 0xFF) / 255
        let g = CGFloat((v >> 8) & 0xFF) / 255
        let b = CGFloat(v & 0xFF) / 255
        return CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    static let all: [Palette] = [
        Palette(id: "duo",      name: "Duo",       hexes: ["#5E5CE6", "#BF5AF2", "#FF375F", "#FF9F0A"]),
        Palette(id: "aurora",   name: "Aurora",    hexes: ["#00D0C0", "#30D158", "#0A84FF", "#5E5CE6"]),
        Palette(id: "sunset",   name: "Sunset",    hexes: ["#FF9F0A", "#FF6B35", "#FF375F", "#8E2DE2"]),
        Palette(id: "midnight", name: "Midnight",  hexes: ["#0B1020", "#16204A", "#2B3A8C", "#5E5CE6"]),
        Palette(id: "mono",     name: "Mono",      hexes: ["#0A0A0B", "#3A3A3C", "#8E8E93", "#E5E5EA"]),
        Palette(id: "ember",    name: "Ember",     hexes: ["#2B0A0A", "#8E1B1B", "#FF453A", "#FFD60A"]),
        Palette(id: "mint",     name: "Mint",      hexes: ["#053B34", "#0F766E", "#2DD4BF", "#A7F3D0"]),
        Palette(id: "bloom",    name: "Bloom",     hexes: ["#FF2D55", "#FF6482", "#FFB3C7", "#FFF0F3"]),
        Palette(id: "deepsea",  name: "Deep Sea",  hexes: ["#01161E", "#053F5C", "#0A84FF", "#64D2FF"]),
        Palette(id: "paper",    name: "Paper",     hexes: ["#F5F2EA", "#E3DCCB", "#C9BFA6", "#8A7F66"]),
        Palette(id: "ink",      name: "Ink",       hexes: ["#000000", "#0A0A0A", "#141414", "#1F1F1F"]),
        Palette(id: "vapor",    name: "Vapor",     hexes: ["#2E1065", "#7C3AED", "#22D3EE", "#F0ABFC"])
    ]

    /// Linear blend between two palette colours, in sRGB.
    static func mix(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
        guard let x = a.components, let y = b.components, x.count >= 3, y.count >= 3 else { return a }
        return CGColor(srgbRed: x[0] + (y[0] - x[0]) * t,
                       green: x[1] + (y[1] - x[1]) * t,
                       blue: x[2] + (y[2] - x[2]) * t,
                       alpha: 1)
    }

    static func named(_ id: String) -> Palette {
        all.first { $0.id == id } ?? all[0]
    }
}
