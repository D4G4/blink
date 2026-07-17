import XCTest
import SwiftUI
import AppKit
@testable import Blink

/// Visual-layout regression guards for the trial screen.
///
/// Two properties must hold together, and they pull against each other — which
/// is exactly why they're both pinned here:
///
///  1. Every interval cue is VERTICALLY CENTERED on the fixation point. The
///     reported "the + drops on an empty flash" bug was an off-center "1"/"2"
///     marker drawn below the box; on an empty flash it was the only thing on
///     screen and read as the "+" falling. Any off-center element unbalances the
///     ink above vs below the fixation center and fails `...CenteredOnFixation`.
///
///  2. An empty flash is VISUALLY DISTINCT from fixation. The first fix over-
///     corrected: the empty flash became identical to fixation, so you couldn't
///     tell when the (empty) interval occurred. `testEmptyFlashIsPerceptible`
///     guards that — the aperture ring must add real ink beyond the bare cross.
///
/// A prior version of this file rigged its measurement band to exclude the
/// marker, so it passed while the bug shipped. These use symmetry about the
/// measured fixation center instead of a hand-picked band.
final class GaborLayoutTests: XCTestCase {

    private let W: CGFloat = 560
    private let H: CGFloat = 900

    @MainActor private func render(stage: TrialStage,
                                   targetInterval: Int = 2,
                                   exercise: ExerciseType = .detection) -> CGImage? {
        let s = GaborExerciseState()
        s.phase = .presenting
        s.currentTrial = 3
        s.sessionSF = 3
        s.exerciseType = exercise
        s.targetInterval = targetInterval
        s.stage = stage
        let view = GaborExerciseView(state: s, theme: .peach, onDismiss: {})
            .frame(width: W, height: H)
        let r = ImageRenderer(content: view)
        r.scale = 1
        return r.cgImage
    }

    private func bytes(_ cg: CGImage) -> (data: [UInt8], w: Int, h: Int)? {
        let w = cg.width, h = cg.height, bpr = w * 4
        var data = [UInt8](repeating: 0, count: h * bpr)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (data, w, h)
    }

    private func maxChannelDiff(_ a: CGImage, _ b: CGImage) -> Int? {
        guard let (da, _, _) = bytes(a), let (db, _, _) = bytes(b), da.count == db.count else { return nil }
        var m = 0
        for i in stride(from: 0, to: da.count, by: 4) {
            m = max(m, abs(Int(da[i]) - Int(db[i])))
            m = max(m, abs(Int(da[i+1]) - Int(db[i+1])))
            m = max(m, abs(Int(da[i+2]) - Int(db[i+2])))
        }
        return m
    }

    /// darkness of a pixel below the ~128 gray field (0 for field/lighter).
    private func dark(_ data: [UInt8], _ i: Int) -> Double {
        let lum = 0.299*Double(data[i]) + 0.587*Double(data[i+1]) + 0.114*Double(data[i+2])
        return max(0.0, 110.0 - lum)
    }

    /// Vertical centroid (pixel row) of dark ink in the stimulus band's central
    /// column. Used only for the small, fully-contained fixation cross.
    private func stimulusCentroidY(_ cg: CGImage) -> CGFloat? {
        guard let (data, w, h) = bytes(cg) else { return nil }
        let bpr = w * 4
        // Stop at 0.60 so the answer prompt (an overlay below the stimulus in
        // the .response stage) can't contaminate the central-cross measurement.
        let yLo = Int(Double(h) * 0.16), yHi = Int(Double(h) * 0.60)
        let xLo = Int(Double(w) * 0.42), xHi = Int(Double(w) * 0.58)
        var wSum = 0.0, ySum = 0.0
        for y in yLo..<yHi {
            for x in xLo..<xHi {
                let i = y * bpr + x * 4
                let d = dark(data, i)
                if d > 0 { wSum += d; ySum += d*Double(y) }
            }
        }
        return wSum > 0 ? CGFloat(ySum / wSum) : nil
    }

    /// Total dark ink strictly above vs strictly below a given row, in the
    /// stimulus band's central column (header/dots above 0.16 and the response
    /// row below 0.80 excluded). A cue centered on `splitY` yields above≈below.
    private func inkAboveBelow(_ cg: CGImage, splitY: CGFloat) -> (above: Double, below: Double)? {
        guard let (data, w, h) = bytes(cg) else { return nil }
        let bpr = w * 4
        let yLo = Int(Double(h) * 0.16), yHi = Int(Double(h) * 0.80)
        let xLo = Int(Double(w) * 0.30), xHi = Int(Double(w) * 0.70)
        var above = 0.0, below = 0.0
        for y in yLo..<yHi {
            for x in xLo..<xHi {
                let d = dark(data, y * bpr + x * 4)
                if d <= 0 { continue }
                if Double(y) < Double(splitY) { above += d } else { below += d }
            }
        }
        return (above, below)
    }

    /// Dark ink in the PERIPHERAL columns of the stimulus band — the left/right
    /// flanks of the box, near the vertical center, where the aperture ring
    /// passes but the small central fixation cross does not. Independent of the
    /// ring's weight vs the cross's: a bare cross (or a blank field) leaves this
    /// ~0; a ring lights it up. This is what proves an empty flash is marked.
    private func peripheralInk(_ cg: CGImage) -> Double? {
        guard let (data, w, h) = bytes(cg) else { return nil }
        let bpr = w * 4
        let yLo = Int(Double(h) * 0.36), yHi = Int(Double(h) * 0.62)
        var sum = 0.0
        for y in yLo..<yHi {
            for x in 0..<w {
                let xf = Double(x) / Double(w)
                let peripheral = (xf >= 0.27 && xf <= 0.40) || (xf >= 0.60 && xf <= 0.73)
                if peripheral { sum += dark(data, y * bpr + x * 4) }
            }
        }
        return sum
    }

    // MARK: - Property 1: cues are centered on the fixation point

    /// THE guard for the reported bug: on an empty flash the cue (aperture ring)
    /// must be balanced above and below the fixation center — nothing sits
    /// off-center below it, as the old "1"/"2" marker did.
    @MainActor func testEmptyFlashIsCenteredOnFixation() {
        guard let fixCg = render(stage: .fixation),
              let fixY = stimulusCentroidY(fixCg),
              // interval 1 is NOT the target (targetInterval = 2) → empty flash.
              let emptyCg = render(stage: .interval(1), targetInterval: 2),
              let (above, below) = inkAboveBelow(emptyCg, splitY: fixY) else {
            return XCTFail("could not render/measure fixation vs empty flash")
        }
        let imbalance = abs(above - below) / max(1.0, above + below)
        XCTAssertLessThan(imbalance, 0.15,
            "empty-flash cue is off-center about the fixation point (above=\(Int(above)) below=\(Int(below))) — something is drawn below center, like the old marker")
    }

    /// The pattern flash must likewise be centered on the fixation point.
    @MainActor func testPatternFlashIsCenteredOnFixation() {
        guard let fixCg = render(stage: .fixation),
              let fixY = stimulusCentroidY(fixCg),
              let patchCg = render(stage: .interval(2), targetInterval: 2),
              let (above, below) = inkAboveBelow(patchCg, splitY: fixY) else {
            return XCTFail("could not render/measure fixation vs pattern flash")
        }
        let imbalance = abs(above - below) / max(1.0, above + below)
        XCTAssertLessThan(imbalance, 0.15,
            "pattern-flash cue is off-center about the fixation point (above=\(Int(above)) below=\(Int(below)))")
    }

    // MARK: - Property 2: an empty flash is perceptible as an interval

    /// Over-correction guard: an empty flash must NOT look identical to
    /// fixation, or you can't tell when the interval happened. The aperture ring
    /// must light up the box periphery, where the bare fixation cross leaves
    /// nothing. (Weight-independent — a soft, thin ring still passes.)
    @MainActor func testEmptyFlashIsPerceptible() {
        guard let fixCg = render(stage: .fixation),
              let emptyCg = render(stage: .interval(1), targetInterval: 2),
              let fixPeri = peripheralInk(fixCg), let emptyPeri = peripheralInk(emptyCg) else {
            return XCTFail("could not render/measure fixation vs empty flash")
        }
        XCTAssertLessThan(fixPeri, 60,
            "fixation already has peripheral ink (\(Int(fixPeri))) — measurement is picking up something other than the ring")
        XCTAssertGreaterThan(emptyPeri, 400,
            "empty flash has almost no peripheral ink (\(Int(emptyPeri))) — the aperture ring is missing/invisible, so the interval isn't perceptible")
    }

    // MARK: - Center stability across stages

    @MainActor func testFixationAndGapRenderIdentically() {
        guard let a = render(stage: .fixation), let b = render(stage: .gap),
              let diff = maxChannelDiff(a, b) else {
            return XCTFail("could not render fixation/gap")
        }
        XCTAssertLessThanOrEqual(diff, 2, "fixation and gap stages render differently (drift)")
    }

    @MainActor func testCrossHoldsCenterWhenResponseButtonsAppear() {
        guard let fixCg = render(stage: .fixation),
              let respCg = render(stage: .response),
              let fix = stimulusCentroidY(fixCg),
              let resp = stimulusCentroidY(respCg) else {
            return XCTFail("could not render/measure")
        }
        XCTAssertEqual(fix, resp, accuracy: 6,
            "fixation cross shifted by \(abs(fix - resp)) px when the response row changed height")
    }

}
