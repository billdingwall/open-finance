#!/usr/bin/env swift
// Renders the Finance Workspace app icon: a brand-accent rounded-rect plate with a centered
// white "$" glyph, then builds App/AppIcon.icns. The accent value mirrors the DESIGN.md `accent`
// token (#3651d3, brand-locked). Run: swift scripts/make-icon.swift
import AppKit

let size: CGFloat = 1024
let repImage = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: repImage)
let ctx = NSGraphicsContext.current!.cgContext

// Brand accent (DESIGN.md token `accent`), with a subtle vertical gradient for native depth.
func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let accent = color(0x3651D3)
let accentTop = color(0x4E68E0)          // a hair lighter at top; same hue family, no 2nd accent

// Apple icon-grid rounded-rect plate: 824×824 centered in 1024, corner radius 185.4.
let inset: CGFloat = 100
let plate = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius: CGFloat = 185.4
let platePath = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)
platePath.addClip()
if let gradient = NSGradient(starting: accentTop, ending: accent) {
    gradient.draw(in: plate, angle: -90)
} else {
    accent.setFill(); plate.fill()
}
NSGraphicsContext.current?.cgContext.resetClip()

// Centered white "$" glyph (SF Pro, heavy). Sized to the plate, optically centered.
let glyph = "$"
let font = NSFont.systemFont(ofSize: size * 0.62, weight: .heavy)
let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
let str = NSAttributedString(string: glyph, attributes: attrs)
let textSize = str.size()
let point = NSPoint(x: (size - textSize.width) / 2,
                    y: (size - textSize.height) / 2 - size * 0.01)  // slight optical nudge
str.draw(at: point)

NSGraphicsContext.restoreGraphicsState()

// Write the 1024 master PNG.
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/finance-icon-1024.png"
guard let data = repImage.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to encode PNG\n".utf8)); exit(1)
}
try! data.write(to: URL(fileURLWithPath: out))
_ = ctx
print("wrote \(out)")
