#include <metal_stdlib>
using namespace metal;

// sRGB opto-electronic transfer function: linear luminance (0…1, where 0.5 is
// the mean/background luminance the Gabor modulates around) → 8-bit display
// code. The Gabor math below is done in LINEAR luminance so that `contrast` is
// physical Michelson contrast (Pelli & Bex 2013; IEC 61966-2-1 sRGB); the
// encode happens only at output. The mid-gray field the patch sits on must be
// the sRGB encoding of linear 0.5 (≈0.735, code 188) — see
// GaborDisplayConfig.meanLuminanceGray — so the Gaussian tail blends with no
// visible disc edge.
inline float linearToSRGB(float c) {
    c = clamp(c, 0.0, 1.0);
    return (c <= 0.0031308) ? (12.92 * c)
                            : (1.055 * pow(c, 1.0 / 2.4) - 0.055);
}

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
// The Gabor is formed in LINEAR luminance (`L`, 0…1, mean 0.5) so `contrast` is
// physical Michelson contrast; `linearToSRGB` encodes to display code only at
// output. `contrast` of 0, or the Gaussian tail, gives L=0.5 → the mid-gray
// field (GaborDisplayConfig.meanLuminanceGray), so there is no disc edge.
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
    float L = clamp(0.5 + 0.5 * contrast * gauss * wave, 0.0, 1.0);   // linear luminance
    return half4(half3(linearToSRGB(L)), 1.0h);
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
    float L = clamp(0.5 + 0.5 * contrast * gauss * plaid, 0.0, 1.0);   // linear luminance
    return half4(half3(linearToSRGB(L)), 1.0h);
}

// Collinear lateral-masking configuration: a low-contrast target flanked by two
// high-contrast Gabors placed ALONG the carrier's orientation axis (the classic
// Polat & Sagi paradigm). All three are summed in ONE pass so their Gaussian
// envelopes overlap at the ~3λ separation without opaque frames occluding each
// other. `separation` is the target-to-flanker distance in points.
[[ stitchable ]]
half4 gaborCollinear(float2 position, half4 color,
                     float2 size, float targetContrast, float flankerContrast,
                     float spatialFreq, float orientation, float phase,
                     float sigma, float separation) {
    float2 p = float2(position.x - size.x * 0.5, size.y * 0.5 - position.y);
    float ct = cos(orientation), st = sin(orientation);
    float twoSig2 = 2.0 * sigma * sigma;
    float k = 2.0 * M_PI_F * spatialFreq;
    float2 axis = float2(-st, ct);          // collinear axis (along the bars)

    float acc = 0.0;                        // signed sum of the three gratings
    float contrasts[3] = { targetContrast, flankerContrast, flankerContrast };
    float2 centers[3] = { float2(0.0), axis * separation, -axis * separation };
    for (int n = 0; n < 3; n++) {
        float2 c = p - centers[n];
        float xp =  c.x * ct + c.y * st;
        float yp = -c.x * st + c.y * ct;
        float g = exp(-(xp * xp + yp * yp) / twoSig2);
        acc += contrasts[n] * g * cos(k * xp + phase);
    }
    float L = clamp(0.5 + 0.5 * acc, 0.0, 1.0);   // linear luminance
    return half4(half3(linearToSRGB(L)), 1.0h);
}
