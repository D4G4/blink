#include <metal_stdlib>
using namespace metal;

// Gabor patch — a sinusoidal grating under a Gaussian envelope — computed
// per pixel on the GPU. This is the Path A renderer: it is applied through
// SwiftUI's `.colorEffect`, so `position` is the pixel's location in the
// view's local coordinate space (POINTS, y-DOWN origin at top-left) and
// `color` is the source pixel, which we ignore because this shader
// *generates* content rather than transforming it.
//
// Contrast is Michelson (0...1). At the patch edges the Gaussian → 0, so the
// output → 0.5, matching the `Color(white: 0.5)` field the patch sits on;
// the taper therefore blends in with no visible disc.
//
// y is FLIPPED (`size.y*0.5 - position.y`) so the displayed tilt handedness
// matches the legacy CPU `GaborRenderer`, against which
// `GaborExerciseState`'s tilt→answer mapping was empirically calibrated.
// This is verified against the CPU renderer at 0 / +30 / -30 deg before it
// is trusted (a mismatch would silently invert every orientation answer).
//
// NOTE: the math is done in gamma/display space to reproduce the current
// look exactly (a pure migration). Physically-correct linear-light contrast
// is a deliberate, separate change that lands with the staircase rework,
// where "contrast" becomes a measured quantity.
[[ stitchable ]]
half4 gaborPatch(float2 position, half4 color,
                 float2 size, float contrast, float spatialFreq,
                 float orientation, float phase, float sigma) {
    float2 c = float2(position.x - size.x * 0.5,
                      size.y * 0.5 - position.y);   // centered, y-up
    float ct = cos(orientation);
    float st = sin(orientation);
    float xp =  c.x * ct + c.y * st;
    float yp = -c.x * st + c.y * ct;
    float gauss = exp(-(xp * xp + yp * yp) / (2.0 * sigma * sigma));
    float wave  = cos(2.0 * M_PI_F * spatialFreq * xp + phase);
    float v = clamp(0.5 + 0.5 * contrast * gauss * wave, 0.0, 1.0);
    return half4(half3(v), 1.0h);
}

// Backward mask — a high-contrast plaid (two orthogonal gratings summed) under
// the same Gaussian window as the target. Flashed briefly after the target to
// curtail processing time: this is the temporal ingredient of the validated
// protocols (Polat 2004 / GlassesOff), the thing that trains speed. It floods
// the same spatial-frequency channels the target used, so it masks contrast
// rather than a specific orientation.
[[ stitchable ]]
half4 gaborMask(float2 position, half4 color,
                float2 size, float contrast, float spatialFreq, float sigma) {
    float2 c = float2(position.x - size.x * 0.5,
                      size.y * 0.5 - position.y);
    float gauss = exp(-(c.x * c.x + c.y * c.y) / (2.0 * sigma * sigma));
    float plaid = 0.5 * (cos(2.0 * M_PI_F * spatialFreq * c.x)
                       + cos(2.0 * M_PI_F * spatialFreq * c.y));   // [-1, 1]
    float v = clamp(0.5 + 0.5 * contrast * gauss * plaid, 0.0, 1.0);
    return half4(half3(v), 1.0h);
}
