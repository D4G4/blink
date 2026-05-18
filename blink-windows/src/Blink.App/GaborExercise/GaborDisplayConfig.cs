using Microsoft.UI.Windowing;
using Windows.Graphics.Display;

namespace Blink.App.GaborExercise;

/// <summary>
/// Computes Gabor patch display parameters from screen DPI and an assumed viewing
/// distance, so patches are sized in degrees of visual angle rather than pixel counts.
///
/// Standard psychophysics viewing distance: 57 cm (arm's length), where 1 cm on
/// screen subtends approximately 1 degree of visual angle.
/// </summary>
public readonly record struct GaborDisplayConfig(
    double ViewingDistanceCm,
    double PixelsPerDegree,
    double PointsPerDegree)
{
    /// <summary>Patch diameter: 4 degrees — standard for contrast sensitivity tasks.</summary>
    public const double PatchSizeDegrees = 4.0;

    /// <summary>
    /// Spatial frequency: 4 cycles per degree — near the peak of human contrast
    /// sensitivity function. Produces clearly resolvable stripes at arm's length.
    /// </summary>
    public const double SpatialFrequencyCpd = 4.0;

    /// <summary>Gaussian envelope standard deviation: 0.65 degrees (roughly patchSize / 6).</summary>
    public const double SigmaDegrees = 0.65;

    /// <summary>
    /// Edge-to-edge gap between adjacent flanker patches, in degrees.
    /// Three levels: close (strong masking), medium, far (weak masking).
    /// </summary>
    public static readonly double[] FlankerGapDegrees = { 1.0, 1.5, 2.0 };

    public const double DefaultViewingDistanceCm = 57.0;

    /// <summary>Patch display size in points (DIPs).</summary>
    public double PatchPointSize => PointsPerDegree * PatchSizeDegrees;

    /// <summary>Patch render size in pixels (at least 256 for quality).</summary>
    public int PatchPixelSize => Math.Max(256, (int)(PixelsPerDegree * PatchSizeDegrees));

    /// <summary>Spatial frequency in cycles per pixel.</summary>
    public double SpatialFrequencyCpp => SpatialFrequencyCpd / PixelsPerDegree;

    /// <summary>Gaussian sigma in pixels.</summary>
    public double SigmaPixels => PixelsPerDegree * SigmaDegrees;

    /// <summary>Flanker edge-to-edge gaps in points, indexed by distance level (0/1/2).</summary>
    public double[] FlankerGapPoints
    {
        get
        {
            var ppd = PointsPerDegree;
            return FlankerGapDegrees.Select(d => ppd * d).ToArray();
        }
    }

    /// <summary>
    /// Create a config from the current display. Uses Win32 GetDeviceCaps for physical
    /// dimensions; falls back to a 96 DPI assumption when unavailable.
    /// </summary>
    public static GaborDisplayConfig Current(double viewingDistanceCm = DefaultViewingDistanceCm)
    {
        var hdc = Native.GetDC(IntPtr.Zero);
        if (hdc == IntPtr.Zero) return Fallback(viewingDistanceCm);

        try
        {
            // Physical screen dimensions in mm
            var widthMm = Native.GetDeviceCaps(hdc, Native.HORZSIZE);
            var heightMm = Native.GetDeviceCaps(hdc, Native.VERTSIZE);
            var widthPx = Native.GetDeviceCaps(hdc, Native.HORZRES);

            if (widthMm <= 0 || widthPx <= 0) return Fallback(viewingDistanceCm);

            // Pixels per real cm
            var widthCm = widthMm / 10.0;
            var pixelsPerCm = widthPx / widthCm;

            // Pixels per degree of visual angle
            var cmPerDegree = 2.0 * viewingDistanceCm * Math.Tan(Math.PI / 360.0);
            var ppd = pixelsPerCm * cmPerDegree;

            // WinUI 3 reports system DPI; "points" (DIPs) are pixels / (dpi/96)
            var logPx = Native.GetDeviceCaps(hdc, Native.LOGPIXELSX);
            var scale = logPx > 0 ? logPx / 96.0 : 1.0;
            var pointsPerDegree = ppd / scale;

            return new GaborDisplayConfig(viewingDistanceCm, ppd, pointsPerDegree);
        }
        finally
        {
            Native.ReleaseDC(IntPtr.Zero, hdc);
        }
    }

    private static GaborDisplayConfig Fallback(double viewingDistanceCm)
    {
        // Typical desktop monitor at 1080p, 24" diagonal, ~96 DPI
        const double ppi = 96.0;
        const double scale = 1.0;
        var pixelsPerCm = ppi / 2.54;
        var cmPerDegree = 2.0 * viewingDistanceCm * Math.Tan(Math.PI / 360.0);
        var ppd = pixelsPerCm * cmPerDegree;
        return new GaborDisplayConfig(viewingDistanceCm, ppd, ppd / scale);
    }

    private static class Native
    {
        public const int HORZSIZE = 4;   // mm
        public const int VERTSIZE = 6;   // mm
        public const int HORZRES = 8;    // pixels
        public const int VERTRES = 10;   // pixels
        public const int LOGPIXELSX = 88;
        public const int LOGPIXELSY = 90;

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern IntPtr GetDC(IntPtr hWnd);

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

        [System.Runtime.InteropServices.DllImport("gdi32.dll")]
        public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
    }
}
