import SwiftUI

/// How a Gabor patch is presented over time.
///
/// `.static` reproduces the legacy still image exactly. The motion cases
/// animate on a display-synced `TimelineView(.animation)` clock — the
/// SwiftUI-native equivalent of a `CADisplayLink` — and are GPU-cheap
/// because only shader uniforms change between frames, never a re-rendered
/// bitmap.
///
/// A note on which motion is which (see the research briefing): smooth
/// `drift` is an *engagement* feature, not a contrast/acuity training
/// mechanism; `flicker` (counterphase) is the narrow, myopia-flavoured
/// temporal signal. The mechanistically-supported "temporal" ingredient —
/// brief presentation + backward masking — is trial-level sequencing, not a
/// property of this view, and lands with the protocol rework.
enum GaborMotion: Equatable {
    /// A still patch (default; visually identical to the old renderer).
    case `static`
    /// Carrier drifts along its orientation axis at `hz` cycles/second.
    case drift(hz: Double)
    /// Contrast reverses in place (counterphase) at `hz` reversals/second.
    case flicker(hz: Double)
}

/// A GPU-rendered Gabor patch (Path A: a `[[stitchable]]` Metal fragment
/// shader applied via `.colorEffect`).
///
/// This replaces the CPU `GaborRenderer` per-pixel loop for the live trial
/// stimulus. Unlike a static `CGImage`, it can update at the display refresh
/// rate, which is what makes drift/flicker — and, later, millisecond-accurate
/// timed presentation — possible without pinning a CPU thread.
///
/// Geometry is all in points; SwiftUI handles Retina scaling, so the shader
/// receives point coordinates directly. The patch is `size × size` points.
struct GaborPatchView: View {
    /// Edge length of the (square) patch, in points.
    let size: CGFloat
    /// Michelson contrast, 0...1. `0` yields a uniform 0.5 gray (the old
    /// `plainGrayImage`).
    var contrast: Double
    /// Carrier spatial frequency in cycles per point.
    var spatialFrequencyCyclesPerPoint: Double
    /// Grating orientation in radians; `0` = vertical stripes.
    var orientation: Double
    /// Base carrier phase in radians.
    var phase: Double = 0
    /// Gaussian envelope standard deviation, in points.
    var sigmaPoints: Double
    /// Temporal presentation. Defaults to a still patch.
    var motion: GaborMotion = .static

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch effectiveMotion {
        case .static:
            patch(phase: phase, contrast: contrast)

        case .drift(let hz):
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                // Reduce modulo one period before converting to Float so the
                // shader never sees a huge (precision-losing) phase value.
                let cycle = hz != 0 ? t.truncatingRemainder(dividingBy: 1.0 / hz) : 0
                patch(phase: phase + 2 * .pi * hz * cycle, contrast: contrast)
            }

        case .flicker(let hz):
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let cycle = hz != 0 ? t.truncatingRemainder(dividingBy: 1.0 / hz) : 0
                patch(phase: phase, contrast: contrast * cos(2 * .pi * hz * cycle))
            }
        }
    }

    /// Honour the system Reduce Motion setting by falling back to a still frame.
    private var effectiveMotion: GaborMotion {
        reduceMotion ? .static : motion
    }

    private func patch(phase: Double, contrast: Double) -> some View {
        Rectangle()
            .fill(Color(white: GaborDisplayConfig.meanLuminanceGray))
            .frame(width: size, height: size)
            .colorEffect(
                ShaderLibrary.gaborPatch(
                    .float2(Float(size), Float(size)),
                    .float(Float(contrast)),
                    .float(Float(spatialFrequencyCyclesPerPoint)),
                    .float(Float(orientation)),
                    .float(Float(phase)),
                    .float(Float(sigmaPoints))
                )
            )
    }
}

/// A GPU-rendered backward mask — a high-contrast plaid (two orthogonal
/// gratings) under the same Gaussian window as the target. Flashed briefly
/// after each interval to curtail processing of the preceding patch. The mask
/// has no orientation, phase, or motion; it floods the same spatial-frequency
/// channels the target used.
struct GaborMaskView: View {
    /// Edge length of the (square) patch, in points.
    let size: CGFloat
    /// Michelson contrast, 0...1. Masks are shown at high contrast.
    var contrast: Double = 0.9
    /// Carrier spatial frequency in cycles per point (match the target's SF).
    var spatialFrequencyCyclesPerPoint: Double
    /// Gaussian envelope standard deviation, in points (match the target).
    var sigmaPoints: Double

    var body: some View {
        Rectangle()
            .fill(Color(white: GaborDisplayConfig.meanLuminanceGray))
            .frame(width: size, height: size)
            .colorEffect(
                ShaderLibrary.gaborMask(
                    .float2(Float(size), Float(size)),
                    .float(Float(contrast)),
                    .float(Float(spatialFrequencyCyclesPerPoint)),
                    .float(Float(sigmaPoints))
                )
            )
    }
}

/// A collinear lateral-masking configuration — a low-contrast target flanked by
/// two high-contrast Gabors along the carrier's orientation axis (the Polat &
/// Sagi paradigm) — composited in a single GPU pass. `targetContrast` of 0
/// renders the flankers alone (the non-target interval).
struct CollinearGaborView: View {
    /// Edge length of the (square) field, in points.
    let size: CGFloat
    /// Michelson contrast of the central target, 0...1.
    var targetContrast: Double
    /// Michelson contrast of the two flankers (high).
    var flankerContrast: Double = 0.9
    var spatialFrequencyCyclesPerPoint: Double
    var orientation: Double
    var phase: Double = 0
    /// Gaussian sigma in points (σ = λ for the classic collinear look).
    var sigmaPoints: Double
    /// Target-to-flanker distance in points (≈ 3λ).
    var separationPoints: Double

    var body: some View {
        Rectangle()
            .fill(Color(white: GaborDisplayConfig.meanLuminanceGray))
            .frame(width: size, height: size)
            .colorEffect(
                ShaderLibrary.gaborCollinear(
                    .float2(Float(size), Float(size)),
                    .float(Float(targetContrast)),
                    .float(Float(flankerContrast)),
                    .float(Float(spatialFrequencyCyclesPerPoint)),
                    .float(Float(orientation)),
                    .float(Float(phase)),
                    .float(Float(sigmaPoints)),
                    .float(Float(separationPoints))
                )
            )
    }
}

/// A thin fixation cross drawn on the mid-gray field between/around flashes so
/// the eye stays centered.
struct FixationCross: View {
    var length: CGFloat = 16
    var thickness: CGFloat = 2
    var color: Color = Color(white: 0.12)

    var body: some View {
        ZStack {
            Capsule().fill(color).frame(width: length, height: thickness)
            Capsule().fill(color).frame(width: thickness, height: length)
        }
    }
}
