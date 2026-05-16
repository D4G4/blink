import AppKit
import SwiftUI

/// Generates Gabor patch images using Core Graphics.
///
/// A Gabor patch is a sinusoidal grating multiplied by a Gaussian envelope:
/// `G(x,y) = 0.5 * (1 + contrast * exp(-(x'² + y'²)/(2σ²)) * cos(2πfx' + φ))`
/// where x' and y' are coordinates rotated by the orientation angle.
/// Contrast is Michelson contrast (0–1): at 1.0 the grating spans the full 0–1 range.
enum GaborRenderer {

    /// Render a Gabor patch as a `CGImage`.
    ///
    /// - Parameters:
    ///   - pixelSize: Width/height in pixels. Use `pointSize * backingScaleFactor` for Retina.
    ///   - contrast: Michelson contrast (0...1). At 1.0 grating spans full black–white range.
    ///   - spatialFrequency: Cycles per pixel. Typical: 0.04–0.08.
    ///   - orientation: Grating orientation in radians. 0 = vertical stripes.
    ///   - phase: Phase offset of the sinusoid in radians.
    ///   - sigma: Gaussian envelope standard deviation in pixels. Defaults to pixelSize/6.
    static func render(
        pixelSize: Int = 256,
        contrast: Double,
        spatialFrequency: Double = 0.05,
        orientation: Double = 0,
        phase: Double = 0,
        sigma: Double? = nil
    ) -> CGImage? {
        let sigma = sigma ?? Double(pixelSize) / 6.0
        let center = Double(pixelSize) / 2.0

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: pixelSize,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        guard let buffer = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }

        let cosTheta = cos(orientation)
        let sinTheta = sin(orientation)
        let twoPiF = 2.0 * .pi * spatialFrequency
        let twoSigmaSq = 2.0 * sigma * sigma

        for py in 0..<pixelSize {
            let rowOffset = py * pixelSize
            let y = Double(py) - center
            for px in 0..<pixelSize {
                let x = Double(px) - center
                let xPrime = x * cosTheta + y * sinTheta
                let yPrime = -x * sinTheta + y * cosTheta
                let gaussian = exp(-(xPrime * xPrime + yPrime * yPrime) / twoSigmaSq)
                let sinusoidal = cos(twoPiF * xPrime + phase)
                let value = 0.5 + 0.5 * contrast * gaussian * sinusoidal
                let clamped = min(max(value, 0.0), 1.0)
                buffer[rowOffset + px] = UInt8(clamped * 255.0)
            }
        }

        return context.makeImage()
    }

    /// Render a Gabor patch as a SwiftUI `Image`, sized for the current display.
    ///
    /// - Parameters:
    ///   - pointSize: Desired display size in points. Rendered at Retina resolution.
    ///   - contrast: Michelson contrast (0...1).
    ///   - spatialFrequency: Cycles per pixel.
    ///   - orientation: Grating angle in radians.
    ///   - phase: Phase offset in radians.
    ///   - sigma: Gaussian width in pixels. Defaults to pixelSize/6.
    static func asImage(
        pointSize: CGFloat = 128,
        contrast: Double,
        spatialFrequency: Double = 0.05,
        orientation: Double = 0,
        phase: Double = 0,
        sigma: Double? = nil
    ) -> Image {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let pixelSize = max(256, Int(pointSize * scale))
        guard let cgImage = render(
            pixelSize: pixelSize,
            contrast: contrast,
            spatialFrequency: spatialFrequency,
            orientation: orientation,
            phase: phase,
            sigma: sigma
        ) else {
            return Image(systemName: "exclamationmark.triangle")
        }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: pointSize, height: pointSize))
        return Image(nsImage: nsImage)
    }

    /// A plain mid-gray circle (no Gabor pattern) matching the patch display size.
    static func plainGrayImage(pointSize: CGFloat = 128) -> Image {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let pixelSize = max(256, Int(pointSize * scale))
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: pixelSize,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return Image(systemName: "circle")
        }

        // Fill with 50% gray
        context.setFillColor(gray: 0.5, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))

        guard let cgImage = context.makeImage() else {
            return Image(systemName: "circle")
        }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: pointSize, height: pointSize))
        return Image(nsImage: nsImage)
    }
}
