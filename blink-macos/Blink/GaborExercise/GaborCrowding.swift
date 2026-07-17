import SwiftUI
import CoreGraphics

/// Which side of fixation the target appears on (the radial flanker axis is the
/// fixation→target line, kept horizontal so its angle to the carrier is constant).
enum CrowdingSide: CaseIterable { case left, right }

/// A rendered crowding stimulus (a small tilted target ± two flankers) plus the
/// tilt it encodes.
struct CrowdingStimulus {
    let image: CGImage
    let sizePt: CGFloat        // square side of the image, target at its center
    let tiltSign: Int          // −1 = leans left, +1 = leans right (the answer)
}

/// Renders the peripheral crowding triplet: a target Gabor tilted ±15° from
/// vertical, flanked on the horizontal (radial) axis by two high-contrast
/// flankers of random orientation at ±spacing (Bouma 1970; Pelli, Palomares &
/// Majaj 2004; Levi 2008). Composited ADDITIVELY in linear luminance and
/// sRGB-encoded once (same pipeline as GaborShader.metal), so the flankers and
/// target overlap correctly when the spacing drives them into the crowding zone.
enum CrowdingRenderer {

    static let cyclesPerPatch = 4.0
    static let contrast = 0.9
    static let tiltDegrees = 15.0

    private struct El { var x: Double; var y: Double; var theta: Double }

    /// - patchPt: target/flanker edge `s` in points.
    /// - spacingPt: target-to-flanker centre distance (= b·E).
    /// - tiltSign: −1 or +1 (the target leans left/right of vertical).
    /// - flankerA/B: flanker orientations (radians); ignored if `flankers` is false.
    /// - flankers: false for the ~10% unflanked catch trials.
    static func render(patchPt s: CGFloat, spacingPt: CGFloat, tiltSign: Int,
                       flankerA: Double, flankerB: Double, flankers: Bool,
                       scale: CGFloat) -> CrowdingStimulus? {
        let sd = Double(s)
        let sp = Double(spacingPt)
        let lambda = sd / cyclesPerPatch
        let sigma = lambda                     // σ = λ (a normal Gabor, unlike contour's 0.5λ)
        let radiusPt = 2.6 * sigma
        let cpp = 1.0 / lambda

        // Image big enough for the outer flankers plus Gaussian tails.
        let side = 2.0 * sp + sd + 4.0 * sigma
        let c = side / 2.0

        // Vertical = orientation 0 in gaborPatch (grating varies in x). Tilt is
        // ± tiltDegrees from vertical.
        let tilt = Double(tiltSign) * tiltDegrees * .pi / 180.0
        var els = [El(x: c, y: c, theta: tilt)]
        if flankers {
            els.append(El(x: c - sp, y: c, theta: flankerA))
            els.append(El(x: c + sp, y: c, theta: flankerB))
        }

        guard let cg = composite(els, sidePt: side, scale: scale,
                                 sigma: sigma, cpp: cpp, radiusPt: radiusPt) else { return nil }
        return CrowdingStimulus(image: cg, sizePt: CGFloat(side), tiltSign: tiltSign)
    }

    private static func linearToSRGB(_ x: Double) -> Double {
        let v = min(max(x, 0), 1)
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1.0 / 2.4) - 0.055
    }

    private static func composite(_ els: [El], sidePt: Double, scale: CGFloat,
                                  sigma: Double, cpp: Double, radiusPt: Double) -> CGImage? {
        let W = Int((sidePt * Double(scale)).rounded()), H = W
        guard W > 0 else { return nil }
        let s = Double(scale)
        var lum = [Double](repeating: 0.5, count: W * H)
        var cover = [Double](repeating: 0.0, count: W * H)   // max envelope per pixel → alpha
        let k = 2.0 * Double.pi * cpp
        let twoSig2 = 2.0 * sigma * sigma
        let radPx = radiusPt * s
        for e in els {
            let ex = e.x * s, ey = e.y * s
            let ct = cos(e.theta), st = sin(e.theta)
            let xLo = max(0, Int(ex - radPx)), xHi = min(W - 1, Int(ex + radPx))
            let yLo = max(0, Int(ey - radPx)), yHi = min(H - 1, Int(ey + radPx))
            if xLo > xHi || yLo > yHi { continue }
            for py in yLo...yHi {
                let dyp = (Double(py) + 0.5) - ey
                let row = py * W
                for px in xLo...xHi {
                    let dxp = (Double(px) + 0.5) - ex
                    let lx = (dxp * ct + dyp * st) / s
                    let ly = (-dxp * st + dyp * ct) / s
                    let g = exp(-(lx * lx + ly * ly) / twoSig2)
                    if g < 0.004 { continue }
                    lum[row + px] += 0.5 * contrast * g * cos(k * lx)
                    if g > cover[row + px] { cover[row + px] = g }
                }
            }
        }
        // Transparent background: alpha follows the Gaussian envelope, so the
        // patches float on the field and nothing (field, fixation) is occluded
        // between them. Premultiplied, so the faded edges blend seamlessly with
        // the identical mean-gray field behind. (No big opaque square.)
        var px = [UInt8](repeating: 0, count: W * H * 4)
        for i in 0..<(W * H) {
            let a = min(1.0, cover[i] * 6.0)
            let v = linearToSRGB(lum[i])
            let o = i * 4
            let pmv = UInt8(max(0, min(255, (v * a * 255.0).rounded())))
            px[o] = pmv; px[o + 1] = pmv; px[o + 2] = pmv
            px[o + 3] = UInt8(max(0, min(255, (a * 255.0).rounded())))
        }
        return px.withUnsafeMutableBytes { raw in
            CGContext(data: raw.baseAddress, width: W, height: H, bitsPerComponent: 8,
                      bytesPerRow: W * 4, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }
}

/// Displays a pre-rendered crowding triplet at the target's eccentricity.
struct CrowdingStimulusView: View {
    let stimulus: CrowdingStimulus

    var body: some View {
        Image(stimulus.image, scale: 1, label: Text("stimulus"))
            .resizable()
            .interpolation(.high)
            .frame(width: stimulus.sizePt, height: stimulus.sizePt)
    }
}
