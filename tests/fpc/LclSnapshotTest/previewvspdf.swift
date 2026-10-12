// The preview against the PDF (macOS, docs/coretext_provider_plan.md, phase 5).
//
// LclSnapshotTest checks positions, clips and colours of the LCL preview, not the glyphs: it
// passed with the Arabic of htmltest drawn letter by letter. This compares the snapshot PNG of
// the preview with the reference PDF the same test writes from the same metafile, rasterized
// at the size of the PNG: the ink of each image must have ink of the other within a few
// pixels. Different glyphs (unjoined Arabic, letters lost or added) lower the match.
//
//   swift previewvspdf.swift snapshot.png snapshot_ref.pdf [pdf min] [preview min] [differences.png]
//
// Prints both fractions and exits with 1 when one is below its minimum: the ink of the PDF found
// in the preview, 0.98 by default (every glyph the PDF draws is in the preview), and the ink of
// the preview found in the PDF, 0.85 by default (the borders of a pen of width 0 are hairlines of
// 0.05 points in the PDF, almost invisible rasterized, and one pixel wide in the preview).
import Foundation
import CoreGraphics
import ImageIO

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(2)
}

let args = CommandLine.arguments
if args.count < 3 { fail("usage: previewvspdf snapshot.png reference.pdf [pdf min] [preview min] [differences.png]") }
let pdfMinimum = args.count > 3 ? Double(args[3]) ?? 0.98 : 0.98
let previewMinimum = args.count > 4 ? Double(args[4]) ?? 0.85 : 0.85

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let preview = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fail("cannot read " + args[1]) }
guard let document = CGPDFDocument(URL(fileURLWithPath: args[2]) as CFURL),
      let page = document.page(at: 1) else { fail("cannot read " + args[2]) }

let width = preview.width, height = preview.height
let gray = CGColorSpaceCreateDeviceGray()

// Grey pixels of an image drawn by the closure, on white
func pixels(_ draw: (CGContext) -> Void) -> [UInt8] {
    var buffer = [UInt8](repeating: 255, count: width * height)
    buffer.withUnsafeMutableBytes { raw in
        let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width, space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        draw(context)
    }
    return buffer
}

let previewPixels = pixels { $0.draw(preview, in: CGRect(x: 0, y: 0, width: width, height: height)) }
let box = page.getBoxRect(.mediaBox)
let pdfPixels = pixels { context in
    context.scaleBy(x: CGFloat(width) / box.width, y: CGFloat(height) / box.height)
    context.translateBy(x: -box.minX, y: -box.minY)
    context.drawPDFPage(page)
}

// Ink: darker than mid grey (text, lines and shapes; light fills do not count). What covers it
// on the other side is any pixel that is not white: a hairline border rasterized from the PDF
// is light grey, while the preview draws it in black, and that is not a difference of glyphs.
func ink(_ p: [UInt8]) -> [Bool] { p.map { $0 < 128 } }
func mark(_ p: [UInt8]) -> [Bool] { p.map { $0 < 235 } }
let a = ink(previewPixels), b = ink(pdfPixels)
let aAny = mark(previewPixels), bAny = mark(pdfPixels)

// The fraction of the ink of `from` with ink of `to` within `radius` pixels
func covered(_ from: [Bool], by to: [Bool], radius: Int) -> (Double, Int) {
    var total = 0, hit = 0
    for y in 0..<height {
        for x in 0..<width where from[y * width + x] {
            total += 1
            var found = false
            var dy = -radius
            while dy <= radius && !found {
                let yy = y + dy
                if yy >= 0 && yy < height {
                    var dx = -radius
                    while dx <= radius {
                        let xx = x + dx
                        if xx >= 0 && xx < width && to[yy * width + xx] { found = true; break }
                        dx += 1
                    }
                }
                dy += 1
            }
            if found { hit += 1 }
        }
    }
    return (total == 0 ? 1 : Double(hit) / Double(total), total)
}

let (previewInPdf, previewInk) = covered(a, by: bAny, radius: 2)
let (pdfInPreview, pdfInk) = covered(b, by: aAny, radius: 2)

// With a fourth argument, an image of the differences: the PDF in light grey, in red the ink
// only the preview has, in blue the ink only the PDF has
if args.count > 5 {
    func near(_ m: [Bool], _ x: Int, _ y: Int) -> Bool {
        for yy in max(0, y - 2)...min(height - 1, y + 2) {
            for xx in max(0, x - 2)...min(width - 1, x + 2) where m[yy * width + xx] { return true }
        }
        return false
    }
    var rgb = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let i = y * width + x, o = i * 4
            if a[i] && !near(bAny, x, y) { rgb[o] = 230; rgb[o + 1] = 0; rgb[o + 2] = 0 }
            else if b[i] && !near(aAny, x, y) { rgb[o] = 0; rgb[o + 1] = 0; rgb[o + 2] = 230 }
            else if b[i] { rgb[o] = 190; rgb[o + 1] = 190; rgb[o + 2] = 190 }
        }
    }
    let space = CGColorSpaceCreateDeviceRGB()
    rgb.withUnsafeMutableBytes { raw in
        let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        if let image = context.makeImage(),
           let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[5]) as CFURL,
                                                             "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
        }
    }
}
print(String(format: "preview ink in the PDF %.3f (%d px), PDF ink in the preview %.3f (%d px)",
             previewInPdf, previewInk, pdfInPreview, pdfInk))
exit(pdfInPreview >= pdfMinimum && previewInPdf >= previewMinimum ? 0 : 1)
