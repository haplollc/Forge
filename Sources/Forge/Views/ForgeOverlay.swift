import SwiftUI

/// The Forge overlay. Designed to live directly above your chat input bar:
/// when collapsed it's a single row matching the input bar's height &
/// styling; when expanded it grows upward in place into a full panel
/// with a sticky toolbar at the top and an edge-to-edge scroll area
/// containing live, animated graphs.
public struct ForgeOverlay: View {
    @StateObject private var store = ForgeStore()
    @ObservedObject private var sink = Forge.shared

    private weak var provider: ForgeProvider?
    private let refreshHz: Double

    @State private var isExpanded = false
    @Namespace private var ns

    public init(provider: ForgeProvider, refreshHz: Double = 4) {
        self.provider = provider
        self.refreshHz = refreshHz
    }

    public var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else {
                collapsedRow
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(barBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            guard !isExpanded else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                isExpanded = true
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: isExpanded)
        .onAppear {
            if let provider { store.attach(provider: provider, refreshHz: refreshHz) }
        }
        .onDisappear { store.detach() }
    }

    // MARK: - Collapsed row (matches an empty input bar's footprint)

    private var collapsedRow: some View {
        HStack(spacing: 10) {
            statusDot

            Text(store.snapshot.modelName ?? "No model loaded")
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .matchedGeometryEffect(id: "model", in: ns)

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                Text(formattedTPS)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .matchedGeometryEffect(id: "tps", in: ns)

            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                Text(formattedMemory)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 28)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Forge debugger. Tap to expand.")
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
                .background(.white.opacity(0.10))
            scrollContent
        }
        .frame(maxHeight: 420)
    }

    private var toolbar: some View {
        ZStack {
            HStack {
                ForgeGlassButton(systemName: "xmark") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        isExpanded = false
                    }
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                Spacer()
                statusDot
            }

            Text("Forge")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .tracking(0.4)
        }
        .frame(height: 44)
        .padding(.horizontal, 14)
    }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                modelHeader

                ForgeChart(
                    title: "Tokens / sec",
                    unit: "t/s",
                    valueLabel: formattedTPSValue,
                    samples: store.tpsHistory,
                    capacity: ForgeStore.historyCapacity,
                    style: .tokensPerSecond(observedPeak: store.observedPeakTPS),
                    isActive: store.snapshot.isGenerating
                )

                ForgeChart(
                    title: "Memory",
                    unit: memoryUnit,
                    valueLabel: memoryValueLabel,
                    samples: store.memoryHistory,
                    capacity: ForgeStore.historyCapacity,
                    style: .memory(budgetMB: store.memoryBudgetMB),
                    isActive: false
                )

                if let progress = contextProgress {
                    ForgeFillBar(
                        title: "Context",
                        valueLabel: contextString,
                        progress: progress,
                        style: .contextUsage
                    )
                }

                metricGrid

                samplerRow
            }
            .padding(.horizontal, 14)
        }
        .scrollBounceBehavior(.basedOnSize)
        .contentMargins(.vertical, 14, for: .scrollContent)
    }

    private var modelHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(store.snapshot.modelName ?? "No model loaded")
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .matchedGeometryEffect(id: "model", in: ns)
            HStack(spacing: 6) {
                if let arch = store.snapshot.modelArchitecture {
                    Text(arch.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                }
                if let status = store.snapshot.statusLabel {
                    Text(status)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForgeMetricTile(title: "First-token",
                            value: firstTokenLatencyString,
                            systemImage: "timer")

            ForgeMetricTile(title: "Tokens",
                            value: tokenCountString,
                            systemImage: "number")

            ForgeMetricTile(title: "Thermal",
                            value: store.thermalLabel,
                            systemImage: "thermometer.medium")

            ForgeMetricTile(title: "Refresh",
                            value: String(format: "%.0f Hz", refreshHz),
                            systemImage: "arrow.clockwise")

            ForEach(store.snapshot.customMetrics) { metric in
                ForgeMetricTile(
                    title: metric.label,
                    value: metric.value,
                    systemImage: metric.systemImage
                )
            }
        }
    }

    @ViewBuilder
    private var samplerRow: some View {
        let temp = store.snapshot.temperature
        let topP = store.snapshot.topP
        let topK = store.snapshot.topK
        if temp != nil || topP != nil || topK != nil {
            HStack(spacing: 8) {
                if let t = temp {
                    samplerTag("temp", String(format: "%.2f", t))
                }
                if let p = topP {
                    samplerTag("top-p", String(format: "%.2f", p))
                }
                if let k = topK {
                    samplerTag("top-k", "\(k)")
                }
                Spacer()
            }
        }
    }

    private func samplerTag(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(.white.opacity(0.05))
        )
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Status dot (pulses while generating)

    private var statusDot: some View {
        let active = store.snapshot.isGenerating
        return Circle()
            .fill(.primary)
            .frame(width: 7, height: 7)
            .opacity(active ? 1.0 : 0.45)
            .modifier(PulseIfActive(active: active))
    }

    // MARK: - Background (matches Haplo input bar styling)

    @ViewBuilder
    private var barBackground: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: - Formatters

    private var formattedTPS: String {
        guard let tps = store.snapshot.tokensPerSecond, tps > 0 else { return "—" }
        return String(format: "%.1f t/s", tps)
    }

    private var formattedTPSValue: String {
        guard let tps = store.snapshot.tokensPerSecond, tps > 0 else { return "—" }
        return String(format: "%.1f", tps)
    }

    private var formattedMemory: String {
        let mb = store.memoryMB
        if mb >= 1024 { return String(format: "%.2f GB", mb / 1024) }
        return String(format: "%.0f MB", mb)
    }

    private var memoryValueLabel: String {
        let mb = store.memoryMB
        if mb >= 1024 { return String(format: "%.2f", mb / 1024) }
        return String(format: "%.0f", mb)
    }

    private var memoryUnit: String {
        store.memoryMB >= 1024 ? "GB" : "MB"
    }

    private var contextString: String {
        let used = store.snapshot.contextUsed
        let window = store.snapshot.contextWindow
        switch (used, window) {
        case let (u?, w?): return "\(u) / \(w)"
        case let (u?, nil): return "\(u)"
        case let (nil, w?): return "— / \(w)"
        default: return "—"
        }
    }

    private var contextProgress: Double? {
        guard let used = store.snapshot.contextUsed,
              let window = store.snapshot.contextWindow,
              window > 0
        else { return nil }
        return min(1.0, Double(used) / Double(window))
    }

    private var tokenCountString: String {
        let prompt = store.snapshot.promptTokens
        let completion = store.snapshot.completionTokens
        switch (prompt, completion) {
        case let (p?, c?): return "\(p) → \(c)"
        case let (nil, c?): return "\(c)"
        case let (p?, nil): return "\(p) → —"
        default: return "—"
        }
    }

    private var firstTokenLatencyString: String {
        guard let ms = store.snapshot.firstTokenLatencyMs else { return "—" }
        if ms >= 1000 { return String(format: "%.2fs", ms / 1000) }
        return String(format: "%.0fms", ms)
    }
}

private struct PulseIfActive: ViewModifier {
    let active: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && pulse ? 1.4 : 1.0)
            .opacity(active && pulse ? 0.5 : 1.0)
            .animation(
                active
                    ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear { pulse = active }
            .onChange(of: active) { _, newValue in pulse = newValue }
    }
}
