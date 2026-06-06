import XCTest
import SwiftUI
import AppKit
@testable import Blink

/// Lightweight snapshot testing — no dependencies.
///
/// **Comparing** (default): if a reference PNG exists in `__Snapshots__/`, the test renders
/// the view and compares pixel-by-pixel. Mismatches write actual + reference PNGs to the
/// container's `__Failures__/` and fail the test.
///
/// **Recording**: set `SNAPSHOT_RECORD=1` in the test process environment and re-run any
/// failing test. The new reference is written DIRECTLY to the source-tree
/// `__Snapshots__/` directory (the test target has `ENABLE_APP_SANDBOX: false`, so file
/// writes outside the container succeed) and the test passes. Commit the regenerated PNGs.
///
/// Bulk regeneration from a clean shell:
///   SNAPSHOT_RECORD=1 xcodebuild -project Blink.xcodeproj -scheme Blink test \
///       -destination 'platform=macOS,arch=arm64' -only-testing:BlinkSnapshotTests
///
/// Recording mode also runs when no reference exists (legacy behavior preserved).
class SnapshotTestCase: XCTestCase {

    /// Source tree directory containing reference PNGs (read via #filePath).
    private var sourceSnapshotDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
    }

    /// Per-test container directory used for mismatch artifacts (actual + reference
    /// pair) so the engineer can `open` them side-by-side. Source-tree references are
    /// regenerated via SNAPSHOT_RECORD=1, not this directory.
    private var writableDir: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BlinkSnapshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// True when SNAPSHOT_RECORD=1 in the test process environment. When true,
    /// every assertion overwrites its source-tree reference and passes — used for
    /// bulk re-recording after a UI change.
    private var isRecordingMode: Bool {
        ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
    }

    /// Snapshot a SwiftUI view and compare against the stored reference.
    /// If no reference exists, records one to the container and prints the path.
    @MainActor func assertSnapshot<V: View>(
        of view: V,
        named name: String,
        width: CGFloat = 500,
        height: CGFloat = 400,
        colorScheme: ColorScheme = .light,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let bgColor: Color = colorScheme == .dark ? Color(nsColor: NSColor(white: 0.12, alpha: 1)) : .white
        let wrapped = ZStack {
            bgColor
            view
        }
        .frame(width: width, height: height)
        .environment(\.colorScheme, colorScheme)

        let renderer = ImageRenderer(content: wrapped)
        renderer.scale = 2.0

        guard let cgImage = renderer.cgImage else {
            XCTFail("ImageRenderer returned nil for \(name)", file: file, line: line)
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let pngData = pngData(from: nsImage) else {
            XCTFail("Failed to create PNG data for \(name)", file: file, line: line)
            return
        }

        compareOrRecord(pngData: pngData, named: name, file: file, line: line)
    }

    /// Snapshot a SwiftUI view via `NSHostingView` instead of `ImageRenderer`.
    ///
    /// Use this for views that contain `ScrollView`, `LazyVStack`, or any
    /// other layout that needs a real AppKit container size to render its
    /// content. `ImageRenderer` doesn't measure those correctly and emits
    /// a blank content area. `NSHostingView` participates in real AppKit
    /// layout, so the content lays out properly. To avoid the ScrollView
    /// actually clipping anything, pass a `height` ≥ the natural content
    /// height — the snapshot will be tall but show everything end-to-end.
    @MainActor func assertHostedSnapshot<V: View>(
        of view: V,
        named name: String,
        width: CGFloat = 500,
        height: CGFloat = 1200,
        colorScheme: ColorScheme = .light,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let appearance: NSAppearance? = colorScheme == .dark
            ? NSAppearance(named: .darkAqua)
            : NSAppearance(named: .aqua)
        let bgColor: Color = colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.12, alpha: 1))
            : .white
        let wrapped = ZStack {
            bgColor
            view
        }
        .environment(\.colorScheme, colorScheme)

        let hosting = NSHostingView(rootView: wrapped)
        hosting.appearance = appearance
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)

        // Attach to an offscreen NSWindow so AppKit gives the hosting view
        // a real layout context. Without this, NSHostingView's layer-backed
        // rendering for ScrollView stays deferred and we get a blank capture.
        let win = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.appearance = appearance
        win.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            XCTFail("NSHostingView produced no bitmap rep for \(name)", file: file, line: line)
            return
        }
        rep.size = hosting.bounds.size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create PNG data for \(name)", file: file, line: line)
            return
        }

        compareOrRecord(pngData: pngData, named: name, file: file, line: line)
    }

    /// Shared comparison + record logic for both ImageRenderer and
    /// NSHostingView-based snapshot paths.
    @MainActor private func compareOrRecord(
        pngData: Data,
        named name: String,
        file: StaticString,
        line: UInt
    ) {
        let refURL = sourceSnapshotDir.appendingPathComponent("\(name).png")

        // Recording mode (SNAPSHOT_RECORD=1) — write to the container's
        // BlinkSnapshots/ directory and pass the test. macOS hardened-runtime
        // and TCC block direct writes to source paths from the test host
        // process; a post-step shell script (scripts/promote-snapshots.sh)
        // copies the freshly-recorded PNGs back into the source tree.
        if isRecordingMode {
            let recordURL = writableDir.appendingPathComponent("\(name).png")
            do {
                try pngData.write(to: recordURL)
                print("📸 Recorded (SNAPSHOT_RECORD=1): \(recordURL.path)")
            } catch {
                XCTFail("Failed to write snapshot \(name) to container: \(error)", file: file, line: line)
            }
            return
        }

        // No reference exists — record it to the container and tell the
        // engineer how to promote it. (Legacy path; SNAPSHOT_RECORD=1 above
        // is the preferred re-record route now.)
        if !FileManager.default.fileExists(atPath: refURL.path) {
            let recordURL = writableDir.appendingPathComponent("\(name).png")
            do {
                try pngData.write(to: recordURL)
                print("📸 Recorded: \(recordURL.path)")
                print("   Copy to source: cp \"\(recordURL.path)\" \"\(refURL.path)\"")
            } catch {
                XCTFail("Failed to write snapshot \(name): \(error)", file: file, line: line)
            }
            return
        }

        // Reference exists — compare
        guard let refData = try? Data(contentsOf: refURL) else {
            XCTFail("Failed to read reference snapshot for \(name)", file: file, line: line)
            return
        }

        // Compare with perceptual tolerance — ImageRenderer output can vary
        // slightly between runs due to anti-aliasing and animation state
        let mismatchFraction = Self.pixelMismatchFraction(pngData, refData)
        let tolerance: Double = 0.005 // 0.5% pixel difference allowed

        if mismatchFraction > tolerance {
            // Write failures to container for inspection
            let failDir = writableDir.appendingPathComponent("__Failures__")
            try? FileManager.default.createDirectory(at: failDir, withIntermediateDirectories: true)
            let actualURL = failDir.appendingPathComponent("\(name)_actual.png")
            let refCopyURL = failDir.appendingPathComponent("\(name)_reference.png")
            try? pngData.write(to: actualURL)
            try? refData.write(to: refCopyURL)

            XCTFail(
                "Snapshot \"\(name)\" does not match reference.\n" +
                "  Actual:    \(actualURL.path)\n" +
                "  Reference: \(refCopyURL.path)\n" +
                "Delete the reference PNG and re-run to update.",
                file: file, line: line
            )
        }
    }

    /// Returns the fraction of pixels that differ *perceptibly* between two PNG
    /// images (0.0 = identical, 1.0 = completely different).
    ///
    /// A pixel counts as different only when its per-channel color delta sums
    /// above `perceptibleDelta`. Exact-equality comparison was too strict:
    /// ImageRenderer emits sub-LSB antialiasing noise that varies run-to-run
    /// (soft shadows, gradients, resampled raster icons), producing 3–14%
    /// exact-different pixels that are 0.000% perceptibly different — enough to
    /// fail the 0.5% tolerance intermittently. A real regression (text/layout/
    /// color change) moves pixels far past this threshold, so it's still caught.
    private static let perceptibleDelta = 0.12  // sum of |Δr|+|Δg|+|Δb|, ~0.04/channel

    private static func pixelMismatchFraction(_ data1: Data, _ data2: Data) -> Double {
        guard let rep1 = NSBitmapImageRep(data: data1),
              let rep2 = NSBitmapImageRep(data: data2) else { return 1.0 }

        let w = min(rep1.pixelsWide, rep2.pixelsWide)
        let h = min(rep1.pixelsHigh, rep2.pixelsHigh)
        guard w > 0, h > 0 else { return 1.0 }

        // Size mismatch counts as full mismatch
        if rep1.pixelsWide != rep2.pixelsWide || rep1.pixelsHigh != rep2.pixelsHigh {
            return 1.0
        }

        var mismatched = 0
        let total = w * h
        for y in 0..<h {
            for x in 0..<w {
                guard let c1 = rep1.colorAt(x: x, y: y),
                      let c2 = rep2.colorAt(x: x, y: y) else { continue }
                let delta = abs(c1.redComponent - c2.redComponent)
                    + abs(c1.greenComponent - c2.greenComponent)
                    + abs(c1.blueComponent - c2.blueComponent)
                if delta > perceptibleDelta { mismatched += 1 }
            }
        }
        return Double(mismatched) / Double(total)
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Helpers for iterating themes

struct ThemeVariant {
    let name: String
    let theme: BlinkTheme
    let colorScheme: ColorScheme

    var snapshotName: String {
        "\(name)_\(colorScheme == .dark ? "dark" : "light")"
    }
}

let allThemeVariants: [ThemeVariant] = {
    let themes: [(String, BlinkTheme)] = [
        ("peach", .peach),
        ("midnight", .midnight),
        ("sage", .sage),
        ("sand", .sand),
        ("mono", .mono),
        ("dark", .dark),
    ]
    return themes.flatMap { name, theme in
        [
            ThemeVariant(name: name, theme: theme, colorScheme: .light),
            ThemeVariant(name: name, theme: theme, colorScheme: .dark),
        ]
    }
}()
