import Foundation

/// The single display constant the Gabor stimulus needs.
///
/// Everything geometric about the stimulus — patch size, cycles-per-patch,
/// σ=λ — is derived at render time from the on-screen size (see `TrialPhase`),
/// NOT from an uncalibrated degrees-of-visual-angle assumption. The old
/// viewing-distance / pixels-per-degree machinery (and its several contradictory
/// σ definitions) was removed as orphaned and misleading: without a measured
/// viewing distance those "degrees" and "cycles/deg" were nominal anyway (see
/// the in-app "The science" note). What remains is the one thing the renderer
/// genuinely requires.
enum GaborDisplayConfig {

    /// The uniform field the Gabor sits on must be the display's MEAN luminance:
    /// the sRGB encoding of linear 0.5, ≈ 0.735 (8-bit code 188). The shader
    /// forms the Gabor in linear luminance and encodes to sRGB at output
    /// (`GaborShader.metal`); at the Gaussian tail the luminance returns to
    /// linear 0.5, so the field must be this value for the patch to blend with
    /// no visible disc edge. (Pelli & Bex 2013; IEC 61966-2-1 sRGB.)
    static let meanLuminanceGray: Double = 0.7353569830524495
}
