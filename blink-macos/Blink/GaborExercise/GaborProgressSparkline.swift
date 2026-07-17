import SwiftUI

/// A small contrast-threshold-over-sessions sparkline for the completion
/// screen. Lower threshold means you detected a fainter pattern, so a downward
/// trend is improvement — the caption says so, and the axis is literal (higher
/// threshold plots higher). Renders nothing until at least two sessions exist,
/// since a single point isn't a trend.
struct GaborProgressSparkline: View {
    let history: [(date: Date, threshold: Double)]
    var tint: Color = .white

    var body: some View {
        if history.count >= 2 {
            let values = history.map(\.threshold)
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = max(maxV - minV, 0.0001)

            VStack(alignment: .leading, spacing: 6) {
                Text("Contrast threshold · last \(history.count) sessions (lower is better)")
                    .font(.system(size: 11))
                    .foregroundStyle(tint.opacity(0.7))

                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let pts: [CGPoint] = values.enumerated().map { i, v in
                        let x = w * CGFloat(i) / CGFloat(values.count - 1)
                        let norm = (v - minV) / range          // 0 = best, 1 = worst
                        let y = h * (1 - CGFloat(norm))        // worst at top, best at bottom
                        return CGPoint(x: x, y: y)
                    }
                    ZStack {
                        Path { p in
                            p.move(to: pts[0])
                            for pt in pts.dropFirst() { p.addLine(to: pt) }
                        }
                        .stroke(tint.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

                        if let last = pts.last {
                            Circle().fill(tint).frame(width: 5, height: 5).position(last)
                        }
                    }
                }
                .frame(height: 40)
            }
        }
    }
}
