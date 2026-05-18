using Microsoft.UI.Xaml.Media.Imaging;
using System.Runtime.InteropServices.WindowsRuntime;

namespace Blink.App.GaborExercise;

/// <summary>
/// Generates Gabor patch images. A Gabor patch is a sinusoidal grating multiplied
/// by a Gaussian envelope:
/// <c>G(x,y) = 0.5 * (1 + contrast * exp(-(x'² + y'²)/(2σ²)) * cos(2πfx' + φ))</c>
/// Contrast is Michelson contrast (0–1).
/// </summary>
public static class GaborRenderer
{
    /// <summary>
    /// Render a Gabor patch into a WriteableBitmap.
    /// </summary>
    /// <param name="pixelSize">Width/height in pixels.</param>
    /// <param name="contrast">Michelson contrast (0..1).</param>
    /// <param name="spatialFrequency">Cycles per pixel. Typical 0.04–0.08.</param>
    /// <param name="orientation">Grating orientation in radians. 0 = vertical stripes.</param>
    /// <param name="phase">Phase offset in radians.</param>
    /// <param name="sigma">Gaussian sigma in pixels. Default pixelSize/6.</param>
    public static WriteableBitmap Render(
        int pixelSize,
        double contrast,
        double spatialFrequency,
        double orientation = 0,
        double phase = 0,
        double? sigma = null)
    {
        var bmp = new WriteableBitmap(pixelSize, pixelSize);
        var pixels = WritePatch(bmp, pixelSize, contrast, spatialFrequency, orientation, phase, sigma);
        using var stream = bmp.PixelBuffer.AsStream();
        stream.Write(pixels, 0, pixels.Length);
        return bmp;
    }

    private static byte[] WritePatch(
        WriteableBitmap _, int pixelSize, double contrast,
        double spatialFrequency, double orientation, double phase, double? sigma)
    {
        var s = sigma ?? pixelSize / 6.0;
        var center = pixelSize / 2.0;
        var cosTheta = Math.Cos(orientation);
        var sinTheta = Math.Sin(orientation);
        var twoPiF = 2.0 * Math.PI * spatialFrequency;
        var twoSigmaSq = 2.0 * s * s;

        // BGRA8 layout — 4 bytes per pixel
        var bytes = new byte[pixelSize * pixelSize * 4];

        for (var py = 0; py < pixelSize; py++)
        {
            var y = py - center;
            for (var px = 0; px < pixelSize; px++)
            {
                var x = px - center;
                var xPrime = x * cosTheta + y * sinTheta;
                var yPrime = -x * sinTheta + y * cosTheta;
                var gaussian = Math.Exp(-(xPrime * xPrime + yPrime * yPrime) / twoSigmaSq);
                var sinusoidal = Math.Cos(twoPiF * xPrime + phase);
                var value = 0.5 + 0.5 * contrast * gaussian * sinusoidal;
                var clamped = Math.Clamp(value, 0.0, 1.0);
                var gray = (byte)(clamped * 255.0);
                var i = (py * pixelSize + px) * 4;
                bytes[i] = gray;      // B
                bytes[i + 1] = gray;  // G
                bytes[i + 2] = gray;  // R
                bytes[i + 3] = 255;   // A
            }
        }
        return bytes;
    }

    /// <summary>Mid-gray (50%) circle bitmap matching patch size — used as the non-target option.</summary>
    public static WriteableBitmap PlainGray(int pixelSize)
    {
        var bmp = new WriteableBitmap(pixelSize, pixelSize);
        var bytes = new byte[pixelSize * pixelSize * 4];
        for (var i = 0; i < bytes.Length; i += 4)
        {
            bytes[i] = 128;
            bytes[i + 1] = 128;
            bytes[i + 2] = 128;
            bytes[i + 3] = 255;
        }
        using var stream = bmp.PixelBuffer.AsStream();
        stream.Write(bytes, 0, bytes.Length);
        return bmp;
    }
}
