#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// DMG window size: 540x380, retina 2x
let width = 1080
let height = 760

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: width, height: height,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create context")
}

// CG is bottom-up, flip to top-down
ctx.translateBy(x: 0, y: CGFloat(height))
ctx.scaleBy(x: 1, y: -1)

// --- Background gradient (warm peach theme) ---
let gradientColors = [
    CGColor(red: 0.98, green: 0.93, blue: 0.88, alpha: 1.0),  // light peach top
    CGColor(red: 0.95, green: 0.88, blue: 0.82, alpha: 1.0),  // warm peach bottom
] as CFArray
let gradient = CGGradient(colorsSpace: cs, colors: gradientColors, locations: [0.0, 1.0])!
// Note: we flipped coords, so "top" in our space is actually bottom in CG
ctx.drawLinearGradient(gradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: 0, y: CGFloat(height)),
    options: [])

// --- Subtle diamond pattern overlay ---
ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 0.15)
let diamondSize: CGFloat = 60
for row in stride(from: -diamondSize, through: CGFloat(height) + diamondSize, by: diamondSize) {
    for col in stride(from: -diamondSize, through: CGFloat(width) + diamondSize, by: diamondSize) {
        let offsetX = Int(row / diamondSize) % 2 == 0 ? 0.0 : diamondSize / 2
        let cx = col + offsetX
        let cy = row
        let half = diamondSize * 0.3
        ctx.move(to: CGPoint(x: cx, y: cy - half))
        ctx.addLine(to: CGPoint(x: cx + half, y: cy))
        ctx.addLine(to: CGPoint(x: cx, y: cy + half))
        ctx.addLine(to: CGPoint(x: cx - half, y: cy))
        ctx.closePath()
    }
}
ctx.fillPath()

// --- Save ---
guard let image = ctx.makeImage() else { fatalError("Failed to make image") }

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/dmg-background.png"

let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Failed to create destination")
}
CGImageDestinationAddImage(dest, image, [
    kCGImagePropertyPixelWidth: width,
    kCGImagePropertyPixelHeight: height,
    kCGImagePropertyDPIWidth: 144,
    kCGImagePropertyDPIHeight: 144,
] as CFDictionary)
CGImageDestinationFinalize(dest)
print("Created: \(outputPath)")
