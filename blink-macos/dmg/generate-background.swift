#!/usr/bin/env swift
import AppKit

// Window: 660x470. Background at @1x to avoid Finder scaling issues.
let w: CGFloat = 660
let h: CGFloat = 470
let footerH: CGFloat = 80

// Icon positions from create-dmg (Finder coords: y from top)
let iconFinderY: CGFloat = 200
// Convert to CG (y from bottom)
let iconCGY: CGFloat = h - iconFinderY
let appX: CGFloat = 175
let dropX: CGFloat = 485
let midX: CGFloat = (appX + dropX) / 2  // 330

let img = NSImage(size: NSSize(width: w, height: h), flipped: false) { rect in
    // White background
    NSColor.white.setFill()
    rect.fill()

    // Cross "+" grid pattern (like Linear)
    let gridColor = NSColor(white: 0.88, alpha: 1.0)
    let spacing: CGFloat = 28
    let armLen: CGFloat = 2.5
    let lineW: CGFloat = 0.5

    gridColor.setStroke()
    for x in stride(from: spacing, to: w, by: spacing) {
        for y in stride(from: footerH + spacing, to: h, by: spacing) {
            let p = NSBezierPath()
            p.lineWidth = lineW
            // Horizontal arm
            p.move(to: NSPoint(x: x - armLen, y: y))
            p.line(to: NSPoint(x: x + armLen, y: y))
            // Vertical arm
            p.move(to: NSPoint(x: x, y: y - armLen))
            p.line(to: NSPoint(x: x, y: y + armLen))
            p.stroke()
        }
    }

    // Rounded inner border
    let inset: CGFloat = 46
    let borderRect = NSRect(
        x: inset, y: footerH + 14,
        width: w - inset * 2, height: h - footerH - 14 - inset + 10
    )
    let border = NSBezierPath(roundedRect: borderRect, xRadius: 14, yRadius: 14)
    NSColor(white: 0.84, alpha: 1.0).setStroke()
    border.lineWidth = 0.8
    border.stroke()

    // Chevron arrows between icons
    let arrowCount = 5
    let arrowSpacing: CGFloat = 20
    let arrowH: CGFloat = 14

    for i in 0..<arrowCount {
        let t = Double(i) / Double(arrowCount - 1)
        let opacity: CGFloat = CGFloat(0.2 + t * 0.6)
        let ax = midX + CGFloat(i - arrowCount / 2) * arrowSpacing

        let p = NSBezierPath()
        p.lineWidth = 2.5
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        p.move(to: NSPoint(x: ax - 5, y: iconCGY + arrowH / 2))
        p.line(to: NSPoint(x: ax + 5, y: iconCGY))
        p.line(to: NSPoint(x: ax - 5, y: iconCGY - arrowH / 2))
        NSColor(white: 0.3, alpha: opacity).setStroke()
        p.stroke()
    }

    // Footer background
    NSColor(white: 0.95, alpha: 1.0).setFill()
    NSRect(x: 0, y: 0, width: w, height: footerH).fill()
    NSColor(white: 0.86, alpha: 1.0).setStroke()
    let divider = NSBezierPath()
    divider.lineWidth = 0.5
    divider.move(to: NSPoint(x: 0, y: footerH))
    divider.line(to: NSPoint(x: w, y: footerH))
    divider.stroke()

    // Footer text (flipped=false, so CG coords: y=0 at bottom)
    // Draw text using attributed strings in a flipped sub-image
    let footerText = NSImage(size: NSSize(width: w, height: footerH), flipped: true) { r in
        let bold: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor(white: 0.28, alpha: 1),
        ]
        let light: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8.5, weight: .regular),
            .foregroundColor: NSColor(white: 0.5, alpha: 1),
        ]

        NSAttributedString(string: "BLINK", attributes: bold).draw(at: NSPoint(x: 36, y: 12))
        NSAttributedString(string: "SMART 20-20-20 EYE BREAK REMINDER", attributes: light).draw(at: NSPoint(x: 36, y: 28))

        let cr = NSAttributedString(string: "COPYRIGHT \u{00A9} 2026", attributes: bold)
        cr.draw(at: NSPoint(x: r.width - cr.size().width - 36, y: 12))
        let dw = NSAttributedString(string: "DESIGNED WITH CARE", attributes: light)
        dw.draw(at: NSPoint(x: r.width - dw.size().width - 36, y: 28))
        return true
    }
    footerText.draw(in: NSRect(x: 0, y: 0, width: w, height: footerH))

    return true
}

// Save as PNG
guard let tiff = img.tiffRepresentation,
      let bmp = NSBitmapImageRep(data: tiff),
      let png = bmp.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render image")
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
try! png.write(to: URL(fileURLWithPath: out))
print("Generated \(out) (\(Int(w))x\(Int(h)))")
