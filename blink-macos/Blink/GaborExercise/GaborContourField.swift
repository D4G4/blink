import SwiftUI
import CoreGraphics

/// Which way the closed contour's pinched (pointed) end faces — the observer's
/// forced-choice answer.
enum ContourFacing: CaseIterable { case left, right }

/// A rendered contour-integration field plus the answer it encodes.
struct ContourField {
    let image: CGImage
    let facing: ContourFacing
    let sizePt: CGFloat
}

/// Small seedable RNG so a field is reproducible (deterministic snapshots).
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// Builds and CPU-renders a contour-integration field: a jittered grid of
/// randomly-oriented distractor Gabors with a closed, co-circular "teardrop"
/// contour of aligned Gabors hidden in it (Field, Hayes & Hess 1993; the closed
/// pointing-shape + left/right judgement follow JOVI / Silverstein et al. 2011).
///
/// It is rendered ONCE per trial as a static image: every element is composited
/// ADDITIVELY in linear luminance (mean 0.5) into an accumulator, then encoded
/// to sRGB a single time — the same linear-light pipeline as `GaborShader.metal`,
/// so contour and neighbouring distractors overlap correctly with no disc edges.
/// A static one-shot image needs no per-frame 200-element shader.
enum ContourFieldRenderer {

    // A slightly sparse grid (bigger, fewer elements than a lab's Δ=1.0 field)
    // so the loop is findable for a first-time, non-lab user — a gentle wellness
    // variant. The spec's density-ratio knob could tighten this later.
    private static let cols = 11
    private static let rows = 11
    private static let contourCount = 16
    private static let contrast = 0.9

    private struct Element { var x: Double; var y: Double; var theta: Double }

    /// - sizePt: field side (square) in points.
    /// - scale: pixels per point (2 on Retina).
    /// - jitterRadians: Δβ — each contour element is rotated off its path
    ///   tangent by ±this (the difficulty variable).
    /// - facing: which way the pinch points.
    /// - seed: RNG seed (fix for deterministic renders/tests).
    static func render(sizePt: CGFloat, scale: CGFloat, jitterRadians: Double,
                       facing: ContourFacing, seed: UInt64,
                       contourOnly: Bool = false) -> CGImage? {
        var rng = SeededRNG(seed: seed)
        let size = Double(sizePt)
        let cellPt = size / Double(cols)
        let lambda = cellPt / 3.0            // 3λ tip-to-tip spacing = one cell
        // Contour-integration elements are COMPACT (σ≈0.5λ, ~1–2 visible cycles)
        // so each reads as a distinct oriented segment and neighbours don't merge
        // — unlike the detection patch's σ=λ. (Field, Hayes & Hess 1993;
        // Roudaia et al. 2013 used σ≈0.37λ.)
        let sigma = 0.5 * lambda
        let radiusPt = 2.6 * sigma           // draw each patch to ~2.6σ (< spacing)
        let cpp = 1.0 / lambda               // cycles per point

        // --- Contour: a closed teardrop, equal-arc-length resampled ---
        let contour = buildContour(size: size, count: contourCount,
                                   jitterRadians: jitterRadians, facing: facing, rng: &rng)

        // --- Distractors: jittered 14×14 grid, vacating cells the contour crosses ---
        var elements = contour
        let vacateDist = 0.72 * cellPt
        if !contourOnly {
        for r in 0..<rows {
            for c in 0..<cols {
                let baseX = (Double(c) + 0.5) * cellPt
                let baseY = (Double(r) + 0.5) * cellPt
                let jx = (Double.random(in: -0.4...0.4, using: &rng)) * cellPt
                let jy = (Double.random(in: -0.4...0.4, using: &rng)) * cellPt
                let x = baseX + jx, y = baseY + jy
                // Vacate if a contour element is close (keeps density uniform).
                if contour.contains(where: { hypot($0.x - x, $0.y - y) < vacateDist }) { continue }
                let theta = Double.random(in: 0..<Double.pi, using: &rng)
                elements.append(Element(x: x, y: y, theta: theta))
            }
        }
        }

        return composite(elements: elements, sizePt: sizePt, scale: scale,
                         sigma: sigma, cpp: cpp, radiusPt: radiusPt)
    }

    /// A closed teardrop loop of `count` co-circular elements. The parametric
    /// teardrop (cos t, sin t · sin(t/2)) has a rounded body and one sharp point
    /// at t=0 (facing +x); mirroring x flips the point to face left. Elements are
    /// resampled to equal arc length, oriented along the local tangent ± Δβ.
    private static func buildContour(size: Double, count: Int, jitterRadians: Double,
                                     facing: ContourFacing, rng: inout SeededRNG) -> [Element] {
        let cx = size / 2, cy = size / 2
        let R = size * 0.26
        let mirror = (facing == .left) ? -1.0 : 1.0

        // Dense sample of the teardrop, then pick `count` points equally spaced
        // by arc length so spacing (≈3λ) is uniform and gives no density cue.
        let dense = 720
        var pts: [(Double, Double)] = []
        pts.reserveCapacity(dense)
        for i in 0..<dense {
            let t = 2.0 * Double.pi * Double(i) / Double(dense)
            let x = mirror * cos(t)
            let y = sin(t) * sin(t / 2.0)
            pts.append((cx + R * x, cy + R * y * 1.15))
        }
        // cumulative arc length
        var cum = [Double](repeating: 0, count: dense + 1)
        for i in 0..<dense {
            let a = pts[i], b = pts[(i + 1) % dense]
            cum[i + 1] = cum[i] + hypot(b.0 - a.0, b.1 - a.1)
        }
        let total = cum[dense]

        var out: [Element] = []
        for k in 0..<count {
            let target = total * Double(k) / Double(count)
            // find segment
            var idx = 0
            while idx < dense && cum[idx + 1] < target { idx += 1 }
            let seg = cum[idx + 1] - cum[idx]
            let f = seg > 0 ? (target - cum[idx]) / seg : 0
            let a = pts[idx], b = pts[(idx + 1) % dense]
            let x = a.0 + (b.0 - a.0) * f
            let y = a.1 + (b.1 - a.1) * f
            // tangent from neighbouring dense points
            let p0 = pts[(idx + dense - 2) % dense], p1 = pts[(idx + 2) % dense]
            let tangent = atan2(p1.1 - p0.1, p1.0 - p0.0)
            // The element's BAR must lie ALONG the tangent so the elements "flow"
            // into a smooth contour, so the grating-variation axis (θ) is the
            // NORMAL = tangent + 90°. Then ± Δβ jitter.
            let dB = Double.random(in: -jitterRadians...jitterRadians, using: &rng)
            out.append(Element(x: x, y: y, theta: tangent + .pi / 2 + dB))
        }
        return out
    }

    /// sRGB opto-electronic transfer (linear→display), matching GaborShader.metal.
    private static func linearToSRGB(_ c: Double) -> Double {
        let v = min(max(c, 0), 1)
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1.0 / 2.4) - 0.055
    }

    /// Composite every element additively in linear luminance, then sRGB-encode.
    private static func composite(elements: [Element], sizePt: CGFloat, scale: CGFloat,
                                  sigma: Double, cpp: Double, radiusPt: Double) -> CGImage? {
        let W = Int((sizePt * scale).rounded()), H = W
        guard W > 0 else { return nil }
        let s = Double(scale)
        var lum = [Double](repeating: 0.5, count: W * H)   // linear luminance accumulator
        let k = 2.0 * Double.pi * cpp
        let twoSig2 = 2.0 * sigma * sigma
        let radPx = radiusPt * s

        for e in elements {
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
                    // to element-local, in POINTS
                    let lx = (dxp * ct + dyp * st) / s
                    let ly = (-dxp * st + dyp * ct) / s
                    let g = exp(-(lx * lx + ly * ly) / twoSig2)
                    if g < 0.004 { continue }
                    let wave = cos(k * lx)
                    lum[row + px] += 0.5 * contrast * g * wave
                }
            }
        }

        // encode to 8-bit sRGB RGBA
        var px = [UInt8](repeating: 0, count: W * H * 4)
        for i in 0..<(W * H) {
            let v = UInt8((linearToSRGB(lum[i]) * 255.0).rounded().clamped(0, 255))
            let o = i * 4
            px[o] = v; px[o + 1] = v; px[o + 2] = v; px[o + 3] = 255
        }
        return px.withUnsafeMutableBytes { raw -> CGImage? in
            guard let ctx = CGContext(data: raw.baseAddress, width: W, height: H,
                                      bitsPerComponent: 8, bytesPerRow: W * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            return ctx.makeImage()
        }
    }
}

private extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(Swift.max(self, lo), hi) }
}

/// LINEAR-domain 1-up/3-down staircase on the contour's orientation jitter Δβ
/// (degrees) — the contour-exercise difficulty variable. Three correct in a row
/// INCREASE Δβ (the loop hides better = harder); one wrong DECREASES it. This
/// converges on 79.4% correct (Levitt 1971). Δβ is linear (not log like the
/// contrast staircase) because it spans 0°, where a multiplicative step is
/// undefined. Threshold = mean of the settled reversals, in degrees.
final class ContourStaircase: ObservableObject {
    @Published private(set) var jitterDeg: Double

    private var consecutiveCorrect = 0
    private var step: Double
    private var lastDir: Int?                     // +1 harder, -1 easier
    private var reversals: [Double] = []
    private(set) var trialResults: [(jitter: Double, correct: Bool)] = []

    private let minJ = 0.0, maxJ = 60.0
    private let initialStep: Double
    private let minStep = 4.0
    private let discard = 2, minSettled = 4

    init(start: Double = 0, initialStep: Double = 8) {
        jitterDeg = start
        step = initialStep
        self.initialStep = initialStep
    }

    var jitterRad: Double { jitterDeg * .pi / 180 }
    var reversalCount: Int { reversals.count }

    func record(correct: Bool) {
        trialResults.append((jitterDeg, correct))
        if correct {
            consecutiveCorrect += 1
            guard consecutiveCorrect >= 3 else { return }
            consecutiveCorrect = 0
            move(+1)                              // harder → more jitter
        } else {
            consecutiveCorrect = 0
            move(-1)                              // easier → less jitter
        }
    }

    private func move(_ dir: Int) {
        if let last = lastDir, last != dir {
            reversals.append(jitterDeg)
            step = max(step * 0.5, minStep)
        }
        jitterDeg = min(max(jitterDeg + Double(dir) * step, minJ), maxJ)
        lastDir = dir
    }

    /// Mean Δβ over the settled reversals (first `discard` dropped). `nil` until
    /// `minSettled` settled reversals exist.
    func threshold() -> Double? {
        let settled = reversals.dropFirst(discard)
        guard settled.count >= minSettled else { return nil }
        let used = Array(settled.suffix(8))
        return used.reduce(0, +) / Double(used.count)
    }

    func reset(start: Double = 0) {
        jitterDeg = start
        step = initialStep
        consecutiveCorrect = 0
        lastDir = nil
        reversals = []
        trialResults = []
    }
}

/// Displays a pre-rendered contour field, sized to a square that fills the field.
struct ContourFieldView: View {
    let field: ContourField

    var body: some View {
        Image(field.image, scale: 1, label: Text("pattern field"))
            .resizable()
            .interpolation(.high)
            .frame(width: field.sizePt, height: field.sizePt)
    }
}
