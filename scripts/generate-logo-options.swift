#!/usr/bin/env swift

import AppKit
import Foundation

struct LogoSpec {
    let filename: String
    let backgroundStart: NSColor
    let backgroundEnd: NSColor
    let symbols: [SymbolSpec]
}

struct SymbolSpec {
    let name: String
    let rect: CGRect
    let color: NSColor
    let alpha: CGFloat
    let shadow: NSShadow?
}

func makeShadow(_ color: NSColor, _ blur: CGFloat, _ dx: CGFloat, _ dy: CGFloat) -> NSShadow {
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = CGSize(width: dx, height: dy)
    return shadow
}

func drawRoundedGradientBackground(in rect: CGRect, start: NSColor, end: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.22, yRadius: rect.height * 0.22)
    path.addClip()

    let gradient = NSGradient(starting: start, ending: end)!
    gradient.draw(in: rect, angle: 90)

    NSColor.white.withAlphaComponent(0.10).setStroke()
    path.lineWidth = rect.width * 0.010
    path.stroke()
}

func drawSymbol(_ spec: SymbolSpec) {
    guard let base = NSImage(systemSymbolName: spec.name, accessibilityDescription: nil) else { return }
    let cfg = NSImage.SymbolConfiguration(pointSize: spec.rect.width, weight: .semibold)
    let sym = base.withSymbolConfiguration(cfg) ?? base

    let colored = sym.withSymbolConfiguration(.init(hierarchicalColor: spec.color)) ?? sym

    if let shadow = spec.shadow {
        NSGraphicsContext.current?.saveGraphicsState()
        shadow.set()
        colored.draw(in: spec.rect, from: .zero, operation: .sourceOver, fraction: spec.alpha)
        NSGraphicsContext.current?.restoreGraphicsState()
    } else {
        colored.draw(in: spec.rect, from: .zero, operation: .sourceOver, fraction: spec.alpha)
    }
}

func renderLogo(size: Int, spec: LogoSpec) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    defer { img.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high

    let s = CGFloat(size)
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    drawRoundedGradientBackground(in: rect, start: spec.backgroundStart, end: spec.backgroundEnd)

    // Subtle glow blob
    NSColor.white.withAlphaComponent(0.10).setFill()
    let blob = NSBezierPath(ovalIn: CGRect(x: s * 0.18, y: s * 0.18, width: s * 0.64, height: s * 0.64))
    blob.fill()

    for s in spec.symbols {
        drawSymbol(s)
    }

    return img
}

func pngData(from image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation else { return nil }
    guard let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("design/logo-options", isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let shadow = makeShadow(.black.withAlphaComponent(0.30), 20, 0, -6)

let specs: [LogoSpec] = [
    LogoSpec(
        filename: "option-a-mic-cursor.png",
        backgroundStart: NSColor(calibratedRed: 0.11, green: 0.27, blue: 0.88, alpha: 1),
        backgroundEnd: NSColor(calibratedRed: 0.58, green: 0.20, blue: 0.92, alpha: 1),
        symbols: [
            SymbolSpec(
                name: "waveform",
                rect: CGRect(x: 1024 * 0.18, y: 1024 * 0.40, width: 1024 * 0.64, height: 1024 * 0.64),
                color: .white,
                alpha: 0.20,
                shadow: nil
            ),
            SymbolSpec(
                name: "mic.fill",
                rect: CGRect(x: 1024 * 0.30, y: 1024 * 0.28, width: 1024 * 0.40, height: 1024 * 0.40),
                color: .white,
                alpha: 0.96,
                shadow: shadow
            ),
            SymbolSpec(
                name: "text.cursor",
                rect: CGRect(x: 1024 * 0.62, y: 1024 * 0.40, width: 1024 * 0.22, height: 1024 * 0.22),
                color: .white,
                alpha: 0.95,
                shadow: shadow
            ),
        ]
    ),
    LogoSpec(
        filename: "option-b-key-waveform.png",
        backgroundStart: NSColor(calibratedRed: 0.02, green: 0.55, blue: 0.62, alpha: 1),
        backgroundEnd: NSColor(calibratedRed: 0.11, green: 0.76, blue: 0.35, alpha: 1),
        symbols: [
            SymbolSpec(
                name: "key.fill",
                rect: CGRect(x: 1024 * 0.22, y: 1024 * 0.26, width: 1024 * 0.56, height: 1024 * 0.56),
                color: .white,
                alpha: 0.95,
                shadow: shadow
            ),
            SymbolSpec(
                name: "waveform.path",
                rect: CGRect(x: 1024 * 0.30, y: 1024 * 0.36, width: 1024 * 0.40, height: 1024 * 0.40),
                color: .white,
                alpha: 0.92,
                shadow: nil
            ),
        ]
    ),
    LogoSpec(
        filename: "option-c-waveform-bolt.png",
        backgroundStart: NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.10, alpha: 1),
        backgroundEnd: NSColor(calibratedRed: 0.93, green: 0.20, blue: 0.36, alpha: 1),
        symbols: [
            SymbolSpec(
                name: "waveform.circle.fill",
                rect: CGRect(x: 1024 * 0.22, y: 1024 * 0.22, width: 1024 * 0.56, height: 1024 * 0.56),
                color: .white,
                alpha: 0.95,
                shadow: shadow
            ),
            SymbolSpec(
                name: "bolt.fill",
                rect: CGRect(x: 1024 * 0.43, y: 1024 * 0.38, width: 1024 * 0.22, height: 1024 * 0.22),
                color: .white,
                alpha: 0.88,
                shadow: nil
            ),
        ]
    ),
]

for spec in specs {
    let img = renderLogo(size: 1024, spec: spec)
    guard let data = pngData(from: img) else { continue }
    let out = outDir.appendingPathComponent(spec.filename)
    try data.write(to: out)
    print("Wrote:", out.path)
}
