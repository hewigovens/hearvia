// Renders the "wave to words" app icon PNGs (same geometry as HearviaMark in HearviaKit/Theme.swift).
// Usage: swift scripts/make_icons.swift   (run from the repo root)
import AppKit
import CoreGraphics
import Foundation

struct Palette { let ground: CGColor; let accent: CGColor; let secondary: CGColor }
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let standard = Palette(ground: rgb(0x141733), accent: rgb(0x8B9CFF), secondary: rgb(0xFFFFFF, 0.55))
let dark = Palette(ground: rgb(0x05060D), accent: rgb(0x8B9CFF), secondary: rgb(0x8B9CFF, 0.45))
let tinted = Palette(ground: rgb(0x000000), accent: rgb(0xD9D9D9), secondary: rgb(0xD9D9D9, 0.45))

let bars = [CGRect(x: 15, y: 40, width: 6, height: 20), CGRect(x: 25, y: 29, width: 6, height: 42), CGRect(x: 35, y: 35, width: 6, height: 30)]
let translation = CGRect(x: 47, y: 38, width: 38, height: 9)
let original = CGRect(x: 47, y: 53, width: 26, height: 9)

/// Draws the mark into `box` (top-left origin units 0...100).
func drawMark(_ ctx: CGContext, _ box: CGRect, _ p: Palette, cornerRadius: CGFloat) {
    let s = box.width / 100
    func r(_ u: CGRect) -> CGRect { CGRect(x: box.minX + u.minX * s, y: box.minY + u.minY * s, width: u.width * s, height: u.height * s) }
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: box, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)); ctx.clip()
    ctx.setFillColor(p.ground); ctx.fill(box)
    ctx.setFillColor(p.accent)
    for b in bars + [translation] {
        let rr = r(b); let rad = min(rr.width, rr.height) / 2
        ctx.addPath(CGPath(roundedRect: rr, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.fillPath()
    }
    ctx.setFillColor(p.secondary)
    let o = r(original); ctx.addPath(CGPath(roundedRect: o, cornerWidth: o.height / 2, cornerHeight: o.height / 2, transform: nil)); ctx.fillPath()
    ctx.restoreGState()
}

func render(_ px: Int, opaque: Bool, _ draw: (CGContext, CGFloat) -> Void) -> Data {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(px)); ctx.scaleBy(x: 1, y: -1) // top-left origin like the 100-unit grid
    ctx.interpolationQuality = .high
    draw(ctx, CGFloat(px))
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

func write(_ data: Data, _ path: String) throws {
    try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try data.write(to: URL(fileURLWithPath: path))
}

// iOS: one 1024 square per appearance; the system applies the mask.
let ios = "Apps/iOS/Assets.xcassets/AppIcon.appiconset"
for (name, palette) in [("icon", standard), ("icon-dark", dark), ("icon-tinted", tinted)] {
    try write(render(1024, opaque: true) { ctx, size in drawMark(ctx, CGRect(x: 0, y: 0, width: size, height: size), palette, cornerRadius: 0) }, "\(ios)/\(name).png")
}

// macOS: Big Sur grid — 824 pt body inset 100 pt, ~185 pt corners, soft drop shadow.
let mac = "Apps/macOS/Assets.xcassets/AppIcon.appiconset"
var macImages: [String] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = points * scale
        let file = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try write(render(px, opaque: false) { ctx, size in
            let k = size / 1024
            let body = CGRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -10 * k), blur: 28 * k, color: rgb(0x000000, 0.35))
            ctx.addPath(CGPath(roundedRect: body, cornerWidth: 185 * k, cornerHeight: 185 * k, transform: nil))
            ctx.setFillColor(standard.ground); ctx.fillPath()
            ctx.restoreGState()
            drawMark(ctx, body, standard, cornerRadius: 185 * k)
        }, "\(mac)/\(file)")
        macImages.append(#"{"filename":"\#(file)","idiom":"mac","scale":"\#(scale)x","size":"\#(points)x\#(points)"}"#)
    }
}

let iosContents = #"""
{"images":[
{"filename":"icon.png","idiom":"universal","platform":"ios","size":"1024x1024"},
{"appearances":[{"appearance":"luminosity","value":"dark"}],"filename":"icon-dark.png","idiom":"universal","platform":"ios","size":"1024x1024"},
{"appearances":[{"appearance":"luminosity","value":"tinted"}],"filename":"icon-tinted.png","idiom":"universal","platform":"ios","size":"1024x1024"}
],"info":{"author":"xcode","version":1}}
"""#
try write(Data(iosContents.utf8), "\(ios)/Contents.json")
try write(Data(#"{"images":[\#n\#(macImages.joined(separator: ",\n"))\#n],"info":{"author":"xcode","version":1}}"#.utf8), "\(mac)/Contents.json")
for catalog in ["Apps/iOS/Assets.xcassets", "Apps/macOS/Assets.xcassets"] {
    try write(Data(#"{"info":{"author":"xcode","version":1}}"#.utf8), "\(catalog)/Contents.json")
}
print("icons written")
