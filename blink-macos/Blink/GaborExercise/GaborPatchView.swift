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
            .fill(Color(white: 0.5))
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
