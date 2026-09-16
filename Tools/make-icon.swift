// Renders Resources/AppIcon.icns. Run via Tools/make-icon.sh — kept as source rather
// than a checked-in binary so the mark can be edited alongside the palettes it echoes.
import AppKit

let side = 1024.0
guard let ctx = CGContext(data: nil, width: Int(side), height: Int(side),
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { exit(1) }

func hex(_ s: String, _ a: CGFloat = 1) -> CGColor {
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

// macOS icons sit in a squircle inset from the canvas edge.
let inset = side * 0.094
let plate = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
let squircle = CGPath(roundedRect: plate, cornerWidth: plate.width * 0.225,
                      cornerHeight: plate.width * 0.225, transform: nil)

ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()

if let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [hex("1B1035"), hex("0A0A18")] as CFArray, locations: [0, 1]) {
    ctx.drawLinearGradient(bg, start: CGPoint(x: plate.minX, y: plate.maxY),
                           end: CGPoint(x: plate.maxX, y: plate.minY), options: [])
}

// The Duo motif: two ribbons crossing, in the palette the app ships as its default.
func ribbon(_ rect: CGRect, _ angle: CGFloat, _ a: CGColor, _ b: CGColor) {
    ctx.saveGState()
    ctx.translateBy(x: rect.midX, y: rect.midY)
    ctx.rotate(by: angle)
    ctx.translateBy(x: -rect.midX, y: -rect.midY)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.height / 2,
                       cornerHeight: rect.height / 2, transform: nil))
    ctx.clip()
    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [a, b] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.midY),
                               end: CGPoint(x: rect.maxX, y: rect.midY), options: [])
    }
    ctx.restoreGState()
}

let rw = plate.width * 1.35, rh = plate.height * 0.30
ribbon(CGRect(x: plate.midX - rw / 2, y: plate.midY + plate.height * 0.055, width: rw, height: rh),
       -0.20, hex("5E5CE6"), hex("BF5AF2"))
ribbon(CGRect(x: plate.midX - rw / 2, y: plate.midY - plate.height * 0.055 - rh, width: rw, height: rh),
       0.20, hex("FF375F"), hex("FF9F0A"))

// The hinge the whole app is about.
ctx.setFillColor(hex("FFFFFF", 0.92))
ctx.fill(CGRect(x: plate.minX + plate.width * 0.14, y: plate.midY - side * 0.0035,
                width: plate.width * 0.72, height: side * 0.007))
ctx.restoreGState()

guard let image = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
