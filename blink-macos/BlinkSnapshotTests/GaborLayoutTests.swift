import XCTest
import SwiftUI
import AppKit
@testable import Blink

/// Visual-layout regression guards for the trial screen — these catch the
/// "moving fixation point" bug that logic tests can't: the fixation cross and
/// the patch must land at the same vertical center on every stage.
final class GaborLayoutTests: XCTestCase {

    private let W: CGFloat = 520
    private let H: CGFloat = 640

    @MainActor private func render(stage: TrialStage, targetInterval: Int = 2) -> CGImage? {
        let s = GaborExerciseState()
        s.phase = .presenting
        s.currentTrial = 3
        s.sessionSF = 3
        s.exerciseType = .detection
        s.targetInterval = targetInterval
        s.stage = stage
        let view = GaborExerciseView(state: s, theme: .peach, onDismiss: {})
            .frame(width: W, height: H)
        let r = ImageRenderer(content: view)
        r.scale = 1
        return r.cgImage
    }

    /// RGBA bytes of a CGImage.
    private func bytes(_ cg: CGImage) -> (data: [UInt8], w: Int, h: Int)? {
        let w = cg.width, h = cg.height, bpr = w * 4
        var data = [UInt8](repeating: 0, count: h * bpr)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (data, w, h)
    }

    /// Vertical centroid (pixel row) of dark ink within the central band, so
    /// only the cross/patch count — not the header, dots, flash marker, or
    /// response buttons.
    @MainActor private func stimulusCentroidY(stage: TrialStage, targetInterval: Int = 2) -> CGFloat? {
        guard let cg = render(stage: stage, targetInterval: targetInterval),
              let (data, w, h) = bytes(cg) else { return nil }
        let bpr = w * 4
        // Central band around the stimulus box: exclude the header/dots (top)
        // AND the flash marker + response row (bottom). The marker sits ~30pt
        // below the box, so keeping yHi at 0.54 measures only the cross/patch.
        let yLo = Int(Double(h) * 0.25), yHi = Int(Double(h) * 0.54)
        let xLo = Int(Double(w) * 0.30), xHi = Int(Double(w) * 0.70)
        var wSum = 0.0, ySum = 0.0
        for y in yLo..<yHi {
            for x in xLo..<xHi {
                let i = y * bpr + x * 4
                let lum = 0.299 * Double(data[i]) + 0.587 * Double(data[i + 1]) + 0.114 * Double(data[i + 2])
                let dark = max(0.0, 110.0 - lum)   // field is ~128 gray; count notably darker pixels
                if dark > 0 { wSum += dark; ySum += dark * Double(y) }
            }
        }
        return wSum > 0 ? CGFloat(ySum / wSum) : nil
    }

    /// THE guard for the reported bug: the fixation cross and the patch must
    /// share a vertical center.
    @MainActor func testFixationCrossAndPatchShareVerticalCenter() {
        guard let fix = stimulusCentroidY(stage: .fixation),
              let patch = stimulusCentroidY(stage: .interval(2), targetInterval: 2) else {
            return XCTFail("could not render/measure the stimulus stages")
        }
        XCTAssertEqual(fix, patch, accuracy: 6,
            "fixation cross and patch drifted apart by \(abs(fix - patch)) px — the stimulus is not holding a fixed center")
    }

    /// The two cross-only stages must render pixel-identically.
    @MainActor func testFixationAndGapRenderIdentically() {
        guard let a = render(stage: .fixation), let b = render(stage: .gap),
              let (da, _, _) = bytes(a), let (db, _, _) = bytes(b), da.count == db.count else {
            return XCTFail("could not render fixation/gap")
        }
        var maxDiff = 0
        for i in stride(from: 0, to: da.count, by: 4) {
            maxDiff = max(maxDiff, abs(Int(da[i]) - Int(db[i])))
        }
        XCTAssertLessThanOrEqual(maxDiff, 2, "fixation and gap stages render differently (drift)")
    }

    /// The cross must not shift when the response buttons appear.
    @MainActor func testCrossCenterStableWhenResponseButtonsAppear() {
        guard let fix = stimulusCentroidY(stage: .fixation),
              let resp = stimulusCentroidY(stage: .response) else {
            return XCTFail("could not render/measure")
        }
        XCTAssertEqual(fix, resp, accuracy: 6,
            "fixation cross shifted by \(abs(fix - resp)) px when the response row changed height")
    }
}
