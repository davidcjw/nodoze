import AppKit

// Renders a 1024×1024 master PNG: white coffee cup on an orange squircle.
// Run:  swift scripts/make_icon.swift <output.png>

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let size = 1024.0

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

// --- Background squircle with vertical orange gradient ---
let margin = 96.0
let rect = CGRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
let radius = (size - margin * 2) * 0.2237            // macOS-style continuous corner
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
path.addClip()

let top = NSColor(srgbRed: 1.00, green: 0.42, blue: 0.16, alpha: 1)   // #FF6B29
let bottom = NSColor(srgbRed: 1.00, green: 0.34, blue: 0.00, alpha: 1) // #FF5700
let gradient = NSGradient(starting: top, ending: bottom)!
gradient.draw(in: rect, angle: -90)

// --- White coffee-cup glyph, centered ---
let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .regular)
if let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    NSColor.white.set()
    let r = CGRect(origin: .zero, size: symbol.size)
    symbol.draw(in: r)
    r.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let glyph = tinted.size
    let drawRect = CGRect(
        x: (size - glyph.width) / 2,
        y: (size - glyph.height) / 2 - size * 0.01,
        width: glyph.width, height: glyph.height)
    tinted.draw(in: drawRect)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("encode failed")
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
