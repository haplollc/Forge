import SwiftUI

/// Drives Forge's chart axes and threshold colors. Built so the package
/// figures out reasonable defaults at runtime — no hard-coded device
/// classes, no per-model assumptions.
public struct ForgeChartStyle: Sendable {
    public enum Direction: Sendable {
        /// Higher values are better (e.g. tokens / sec).
        case higherIsBetter
        /// Lower values are better (e.g. memory pressure).
        case lowerIsBetter
    }

    public var domain: ClosedRange<Double>
    public var direction: Direction
    public var nominalThreshold: Double   // ≤ this fraction of `domain.upperBound` reads green
    public var warningThreshold: Double   // ≤ this fraction reads yellow
    public var dangerThreshold: Double    // ≤ this fraction reads orange; above ⇒ red

    public init(
        domain: ClosedRange<Double>,
        direction: Direction,
        nominal: Double = 0.5,
        warning: Double = 0.7,
        danger: Double = 0.85
    ) {
        self.domain = domain
        self.direction = direction
        self.nominalThreshold = nominal
        self.warningThreshold = warning
        self.dangerThreshold = danger
    }

    /// Color for a value, mapped through this style's thresholds.
    public func color(for value: Double) -> Color {
        let span = max(domain.upperBound - domain.lowerBound, 0.0001)
        let normalized = max(0, min(1, (value - domain.lowerBound) / span))

        switch direction {
        case .lowerIsBetter:
            if normalized <= nominalThreshold { return .green }
            if normalized <= warningThreshold { return .yellow }
            if normalized <= dangerThreshold { return .orange }
            return .red
        case .higherIsBetter:
            if normalized >= dangerThreshold { return .green }
            if normalized >= warningThreshold { return .yellow }
            if normalized >= nominalThreshold { return .orange }
            return .red
        }
    }

    /// Vertical gradient (bottom → top) of the threshold zones in this
    /// style — used as the line / area `foregroundStyle` so the chart
    /// stroke takes on the appropriate color at each Y position.
    public var verticalGradient: LinearGradient {
        let stops: [Gradient.Stop]
        switch direction {
        case .lowerIsBetter:
            // bottom (low / good) → top (high / bad)
            stops = [
                .init(color: .green,  location: 0),
                .init(color: .green,  location: nominalThreshold),
                .init(color: .yellow, location: nominalThreshold),
                .init(color: .yellow, location: warningThreshold),
                .init(color: .orange, location: warningThreshold),
                .init(color: .orange, location: dangerThreshold),
                .init(color: .red,    location: dangerThreshold),
                .init(color: .red,    location: 1)
            ]
        case .higherIsBetter:
            // bottom (low / bad) → top (high / good)
            stops = [
                .init(color: .red,    location: 0),
                .init(color: .red,    location: nominalThreshold),
                .init(color: .orange, location: nominalThreshold),
                .init(color: .orange, location: warningThreshold),
                .init(color: .yellow, location: warningThreshold),
                .init(color: .yellow, location: dangerThreshold),
                .init(color: .green,  location: dangerThreshold),
                .init(color: .green,  location: 1)
            ]
        }
        return LinearGradient(gradient: Gradient(stops: stops),
                              startPoint: .bottom, endPoint: .top)
    }

    /// Same gradient but softened — used for the area fill under the line.
    public var verticalAreaGradient: LinearGradient {
        let stops: [Gradient.Stop]
        switch direction {
        case .lowerIsBetter:
            stops = [
                .init(color: Color.green.opacity(0.05),  location: 0),
                .init(color: Color.green.opacity(0.18),  location: nominalThreshold),
                .init(color: Color.yellow.opacity(0.18), location: nominalThreshold),
                .init(color: Color.yellow.opacity(0.22), location: warningThreshold),
                .init(color: Color.orange.opacity(0.22), location: warningThreshold),
                .init(color: Color.orange.opacity(0.28), location: dangerThreshold),
                .init(color: Color.red.opacity(0.28),    location: dangerThreshold),
                .init(color: Color.red.opacity(0.36),    location: 1)
            ]
        case .higherIsBetter:
            stops = [
                .init(color: Color.red.opacity(0.36),    location: 0),
                .init(color: Color.red.opacity(0.28),    location: nominalThreshold),
                .init(color: Color.orange.opacity(0.28), location: nominalThreshold),
                .init(color: Color.orange.opacity(0.22), location: warningThreshold),
                .init(color: Color.yellow.opacity(0.22), location: warningThreshold),
                .init(color: Color.yellow.opacity(0.18), location: dangerThreshold),
                .init(color: Color.green.opacity(0.18),  location: dangerThreshold),
                .init(color: Color.green.opacity(0.05),  location: 1)
            ]
        }
        return LinearGradient(gradient: Gradient(stops: stops),
                              startPoint: .bottom, endPoint: .top)
    }
}

extension ForgeChartStyle {
    /// Default style for memory in megabytes. Domain is the live process
    /// memory budget reported by the OS.
    static func memory(budgetMB: Double) -> ForgeChartStyle {
        let cap = max(budgetMB, 256)   // sanity floor
        return ForgeChartStyle(
            domain: 0...cap,
            direction: .lowerIsBetter,
            nominal: 0.55,
            warning: 0.75,
            danger: 0.88
        )
    }

    /// Default style for tokens-per-second. Auto-grows to accommodate the
    /// observed peak so we don't squash tall spikes against the ceiling.
    static func tokensPerSecond(observedPeak: Double) -> ForgeChartStyle {
        // Stable axis at low TPS; expand if a peak goes higher.
        let cap = max(30, observedPeak * 1.2)
        return ForgeChartStyle(
            domain: 0...cap,
            direction: .higherIsBetter,
            nominal: 0.15,
            warning: 0.30,
            danger: 0.55
        )
    }

    /// Default style for context-window usage (0…1).
    static var contextUsage: ForgeChartStyle {
        ForgeChartStyle(
            domain: 0...1,
            direction: .lowerIsBetter,
            nominal: 0.55,
            warning: 0.75,
            danger: 0.90
        )
    }
}
