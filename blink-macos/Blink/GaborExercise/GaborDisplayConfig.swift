import AppKit

/// Computes Gabor patch display parameters from the screen's physical properties
/// and an assumed viewing distance, so patches are sized in degrees of visual angle
/// rather than arbitrary pixel counts.
///
/// Standard psychophysics viewing distance: 57 cm (arm's length), where 1 cm on
/// screen subtends approximately 1 degree of visual angle.
struct GaborDisplayConfig {

    /// Viewing distance in centimeters.
    let viewingDistanceCM: Double

    /// Physical pixels per degree of visual angle on the current display.
    let pixelsPerDegree: Double

    /// Points per degree of visual angle (pixels / backingScaleFactor).
    let pointsPerDegree: Double

    // MARK: - Standard parameters (degrees of visual angle)

    /// Patch diameter: 4 degrees — standard for contrast sensitivity tasks.
    static let patchSizeDegrees: Double = 4.0

    /// Spatial frequency: 4 cycles per degree — near the peak of human contrast
    /// sensitivity function. Produces clearly resolvable stripes at arm's length.
    static let spatialFrequencyCPD: Double = 4.0

    /// Gaussian envelope standard deviation: 0.65 degrees (roughly patchSize / 6).
    static let sigmaDegrees: Double = 0.65

    /// Edge-to-edge gap between adjacent flanker patches, in degrees.
    /// Three levels: close (strong masking), medium, far (weak masking).
    static let flankerGapDegrees: [Double] = [1.0, 1.5, 2.0]

    // MARK: - Derived values for renderer

    /// Patch display size in points.
    var patchPointSize: CGFloat {
        CGFloat(pointsPerDegree * Self.patchSizeDegrees)
    }

    /// Patch render size in pixels (at least 256 for quality).
    var patchPixelSize: Int {
        max(256, Int(pixelsPerDegree * Self.patchSizeDegrees))
    }

    /// Spatial frequency in cycles per pixel (for `GaborRenderer`).
    var spatialFrequencyCPP: Double {
        Self.spatialFrequencyCPD / pixelsPerDegree
    }

    /// Gaussian sigma in pixels (for `GaborRenderer`).
    var sigmaPixels: Double {
        pixelsPerDegree * Self.sigmaDegrees
    }

    /// Spatial frequency in cycles per point (for `GaborPatchView` / the
    /// Metal shader, which works in point coordinates).
    var spatialFrequencyCyclesPerPoint: Double {
        Self.spatialFrequencyCPD / pointsPerDegree
    }

    /// Gaussian sigma in points (for `GaborPatchView` / the Metal shader).
    var sigmaPoints: Double {
        pointsPerDegree * Self.sigmaDegrees
    }

    // MARK: - Per-session spatial frequency (multi-SF rotation)

    /// Carrier spatial frequency in cycles per point for an arbitrary
    /// cycles-per-degree value (the per-session SF is chosen at runtime).
    func cyclesPerPoint(forCPD cpd: Double) -> Double {
        cpd / pointsPerDegree
    }

    /// Gaussian sigma in points for an arbitrary cycles-per-degree value.
    /// Sigma is fixed at two carrier wavelengths (λ = 1/cpd degrees), so the
    /// envelope scales with the grating and always shows a comparable number
    /// of visible cycles.
    func sigmaPoints(forCPD cpd: Double) -> Double {
        pointsPerDegree * 2.0 / cpd
    }

    /// Flanker edge-to-edge gaps converted to points, indexed by distance level (0, 1, 2).
    var flankerGapPoints: [CGFloat] {
        Self.flankerGapDegrees.map { CGFloat(pointsPerDegree * $0) }
    }

    // MARK: - Factory

    /// Standard viewing distance for desktop work (arm's length).
    static let defaultViewingDistanceCM: Double = 57.0

    /// Create a config for the current main screen at the given viewing distance.
    static func current(viewingDistanceCM: Double = defaultViewingDistanceCM) -> GaborDisplayConfig {
        guard let screen = NSScreen.main,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else {
            return fallback(viewingDistanceCM: viewingDistanceCM)
        }

        let backingScale = Double(screen.backingScaleFactor)
        let physicalSizeMM = CGDisplayScreenSize(displayID)
        guard physicalSizeMM.width > 0 else {
            return fallback(viewingDistanceCM: viewingDistanceCM)
        }

        let physicalWidthCM = Double(physicalSizeMM.width) / 10.0
        let pixelWidth = Double(screen.frame.width) * backingScale
        let ppi = pixelWidth / (physicalWidthCM / 2.54)

        let pixelsPerCM = ppi / 2.54
        let cmPerDegree = 2.0 * viewingDistanceCM * tan(.pi / 360.0)
        let ppd = pixelsPerCM * cmPerDegree

        return GaborDisplayConfig(
            viewingDistanceCM: viewingDistanceCM,
            pixelsPerDegree: ppd,
            pointsPerDegree: ppd / backingScale
        )
    }

    /// Fallback when screen info is unavailable — assumes a typical Retina MacBook (~226 PPI, 2x).
    private static func fallback(viewingDistanceCM: Double) -> GaborDisplayConfig {
        let ppi: Double = 226
        let backingScale: Double = 2.0
        let pixelsPerCM = ppi / 2.54
        let cmPerDegree = 2.0 * viewingDistanceCM * tan(.pi / 360.0)
        let ppd = pixelsPerCM * cmPerDegree
        return GaborDisplayConfig(
            viewingDistanceCM: viewingDistanceCM,
            pixelsPerDegree: ppd,
            pointsPerDegree: ppd / backingScale
        )
    }
}
