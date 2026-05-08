import SwiftUI
import Charts

/// A small, hand-tuned sparkline used inside the Forge panel.
///
/// Visual recipe:
///   • Catmull-Rom interpolation for smooth curves
///   • Monochrome white-on-glass gradient
///   • Faint area fill that fades to transparent at the bottom
///   • A pulsing dot at the latest sample
///   • Smooth value-change animation when new samples arrive
struct ForgeChart: View {
    let title: String
    let unit: String
    let valueLabel: String
    let samples: [ForgeStore.Sample]
    let isActive: Bool

    private var minValue: Double { samples.map(\.value).min() ?? 0 }
    private var maxValue: Double {
        let m = samples.map(\.value).max() ?? 1
        return m == 0 ? 1 : m
    }
    private var domain: ClosedRange<Double> {
        let pad = (maxValue - minValue) * 0.15
        let lo = max(0, minValue - pad)
        let hi = maxValue + pad
        return lo == hi ? lo...(hi + 1) : lo...hi
    }

    private var lastSampleId: Int? { samples.last?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Text(valueLabel)
                    .font(.system(.callout, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            chart
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        Chart(samples) { sample in
            AreaMark(
                x: .value("idx", sample.id),
                yStart: .value("base", domain.lowerBound),
                yEnd: .value("v", sample.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        .primary.opacity(0.22),
                        .primary.opacity(0.02)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )

            LineMark(
                x: .value("idx", sample.id),
                y: .value("v", sample.value)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        .primary.opacity(0.95),
                        .primary.opacity(0.55)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )

            if sample.id == lastSampleId {
                PointMark(
                    x: .value("idx", sample.id),
                    y: .value("v", sample.value)
                )
                .symbolSize(isActive ? 38 : 22)
                .foregroundStyle(.primary)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: domain)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .animation(.easeInOut(duration: 0.5), value: samples.last?.value ?? 0)
        .animation(.easeInOut(duration: 0.5), value: samples.count)
    }
}

/// A horizontal "fill" bar — used for context-window usage. Animates between
/// values smoothly.
struct ForgeFillBar: View {
    let title: String
    let valueLabel: String
    let progress: Double   // 0...1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Text(valueLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.primary.opacity(0.85), .primary.opacity(0.45)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, geo.size.width * max(0, min(1, progress))))
                        .animation(.easeInOut(duration: 0.5), value: progress)
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
