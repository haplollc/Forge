import SwiftUI
import Charts

/// A small, hand-tuned sparkline used inside the Forge panel.
///
/// Visual recipe:
///   • Catmull-Rom interpolation for smooth curves
///   • Threshold-zoned vertical color gradient (green → yellow → orange → red)
///   • Faint area fill in matching tones
///   • A pulsing dot at the latest sample, colored by current value
///   • Smooth value-change animation when new samples arrive
///   • Fixed 0…max Y axis (driven by `style.domain`) — no auto-rescaling
///   • Fixed X axis 0…(capacity − 1) — line starts on the left and
///     scrolls left once the buffer fills
struct ForgeChart: View {
    let title: String
    let unit: String
    let valueLabel: String
    let samples: [ForgeStore.Sample]
    let capacity: Int
    let style: ForgeChartStyle
    let isActive: Bool

    private var latestValue: Double { samples.last?.value ?? 0 }
    private var latestColor: Color { style.color(for: latestValue) }

    private var indexedSamples: [(idx: Int, value: Double)] {
        samples.enumerated().map { ($0.offset, $0.element.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Text(valueLabel)
                    .font(.system(.callout, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(latestColor)
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            chart
                .frame(height: 64)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var chart: some View {
        Chart {
            // Subtle danger band — purely decorative reference for the eye
            RuleMark(y: .value("danger", style.domain.upperBound * style.dangerThreshold))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                .foregroundStyle(.white.opacity(0.10))

            ForEach(indexedSamples, id: \.idx) { sample in
                AreaMark(
                    x: .value("idx", sample.idx),
                    yStart: .value("base", style.domain.lowerBound),
                    yEnd: .value("v", sample.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(style.verticalAreaGradient)

                LineMark(
                    x: .value("idx", sample.idx),
                    y: .value("v", sample.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .foregroundStyle(style.verticalGradient)
            }

            if let last = indexedSamples.last {
                PointMark(
                    x: .value("idx", last.idx),
                    y: .value("v", last.value)
                )
                .symbolSize(isActive ? 44 : 26)
                .foregroundStyle(latestColor)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: 0...max(1, capacity - 1))
        .chartYScale(domain: style.domain)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .animation(.easeInOut(duration: 0.45), value: samples.last?.value ?? 0)
        .animation(.easeInOut(duration: 0.45), value: samples.count)
    }
}

/// A horizontal "fill" bar — used for context-window usage. Animates
/// between values smoothly and adopts the threshold color of the current
/// fill ratio.
struct ForgeFillBar: View {
    let title: String
    let valueLabel: String
    let progress: Double   // 0...1
    let style: ForgeChartStyle

    private var color: Color { style.color(for: progress * style.domain.upperBound) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Text(valueLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.95), color.opacity(0.55)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, geo.size.width * max(0, min(1, progress))))
                        .animation(.easeInOut(duration: 0.45), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }
}
