import AppKit
import QuartzCore

/// Offscreen renderer used to eyeball every transition without a display.
///
/// Runs each transition in `.snapshot` mode — the timeline writes interpolated values
/// straight onto the layers — and rasterises with `CALayer.render(in:)`, which honours
/// masks but ignores running animations. Debug-only: `--contact-sheet <dir> [palette]`.
enum ContactSheet {

    static func run(outputDirectory: String, paletteID: String) {
        let dir = URL(fileURLWithPath: (outputDirectory as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let palette = Palette.named(paletteID)
        let frameSize = CGSize(width: 340, height: 213)
        let stops: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
        let perSheet = 4

        var sheetIndex = 0
        for chunk in stride(from: 0, to: TransitionLibrary.all.count, by: perSheet) {
            let group = Array(TransitionLibrary.all[chunk..<min(chunk + perSheet, TransitionLibrary.all.count)])
            let sheetW = Int(frameSize.width) * stops.count
            let sheetH = Int(frameSize.height) * group.count

            guard let ctx = CGContext(data: nil, width: sheetW, height: sheetH,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { continue }

            for (row, transition) in group.enumerated() {
                for (col, progress) in stops.enumerated() {
                    // Rows run top-to-bottom; CGContext's origin is bottom-left.
                    let rect = CGRect(x: CGFloat(col) * frameSize.width,
                                      y: CGFloat(group.count - 1 - row) * frameSize.height,
                                      width: frameSize.width, height: frameSize.height)
                    ctx.saveGState()
                    ctx.translateBy(x: rect.minX, y: rect.minY)
                    drawFrame(transition, progress: progress, size: frameSize, palette: palette, into: ctx)
                    ctx.restoreGState()
                    ctx.setStrokeColor(NSColor.black.cgColor)
                    ctx.stroke(rect, width: 1)
                }
            }

            guard let image = ctx.makeImage() else { continue }
            let url = dir.appendingPathComponent("sheet\(sheetIndex)-\(group.map(\.id).joined(separator: "-")).png")
            write(image, to: url)
            print(url.path)
            sheetIndex += 1
        }
        exit(0)
    }

    /// One frame, played `.closing`: progress 0 is a clear desktop, progress 1 is full coverage.
    private static func drawFrame(_ transition: Transition,
                                  progress: Double,
                                  size: CGSize,
                                  palette: Palette,
                                  into ctx: CGContext) {
        // render(in:) does not honour the root layer's masksToBounds, so layers animated
        // off-screen would otherwise bleed into the neighbouring cells of the sheet.
        ctx.clip(to: CGRect(origin: .zero, size: size))

        // Stand-in for the desktop, so it is obvious what is covered and what is not.
        checkerboard(size: size, into: ctx)

        let context = TransitionContext(size: size, direction: .closing, palette: palette,
                                        duration: 1.0, scale: 1, startTime: 0,
                                        mode: .snapshot(progress))
        let layer = TransitionRenderer.makeLayer(transition, ctx: context)

        // The layer tree is authored y-down; CGContext is y-up.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        layer.isGeometryFlipped = false
        layer.render(in: ctx)
        ctx.restoreGState()
    }

    static func single(_ id: String, progress: Double, path: String) {
        let size = CGSize(width: 340, height: 213)
        let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
        drawFrame(TransitionLibrary.transition(for: id), progress: progress,
                  size: size, palette: Palette.all[0], into: ctx)
        write(ctx.makeImage()!, to: URL(fileURLWithPath: path))
        print("wrote \(path)")
        exit(0)
    }

    private static func checkerboard(size: CGSize, into ctx: CGContext) {
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.setFillColor(NSColor(white: 0.74, alpha: 1).cgColor)
        let step: CGFloat = 26
        var y: CGFloat = 0, row = 0
        while y < size.height {
            var x: CGFloat = 0, col = 0
            while x < size.width {
                if (row + col) % 2 == 0 { ctx.fill(CGRect(x: x, y: y, width: step, height: step)) }
                x += step; col += 1
            }
            y += step; row += 1
        }
    }

    private static func write(_ image: CGImage, to url: URL) {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }
}
