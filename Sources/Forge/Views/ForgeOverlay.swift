import SwiftUI

/// The Forge overlay. Pin to the top of any view via the `.forgeOverlay()`
/// modifier, or embed manually if you need bespoke placement.
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
        ZStack(alignment: .top) {
            if isExpanded {
                expandedPanel
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.94, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.94, anchor: .top).combined(with: .opacity)
                    ))
            } else {
                collapsedBar
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: isExpanded)
        .onAppear {
            if let provider { store.attach(provider: provider, refreshHz: refreshHz) }
        }
        .onDisappear { store.detach() }
    }

    // MARK: - Collapsed (bar)

    private var collapsedBar: some View {
        HStack(spacing: 10) {
            statusDot
            Text(store.snapshot.modelName ?? "No model loaded")
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .matchedGeometryEffect(id: "model", in: ns)

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                Text(formattedTPS)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(store.snapshot.isGenerating ? .orange : .secondary)
            .matchedGeometryEffect(id: "tps", in: ns)

            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                Text(formattedMemory)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .forgeGlass(cornerRadius: 22)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                isExpanded = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Forge debugger. Tap to expand.")
    }

    // MARK: - Expanded (panel)

    private var expandedPanel: some View {
        VStack(spacing: 12) {
            ZStack {
                HStack {
                    ForgeGlassButton(systemName: "xmark") {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                            isExpanded = false
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                    Spacer()
                }
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("Forge")
                        .font(.subheadline.weight(.semibold))
                }
                HStack {
                    Spacer()
                    statusDot
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(store.snapshot.modelName ?? "No model loaded")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .matchedGeometryEffect(id: "model", in: ns)
                if let arch = store.snapshot.modelArchitecture {
                    Text(arch.uppercased())
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if let status = store.snapshot.statusLabel {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(store.snapshot.isGenerating ? .orange : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForgeMetricTile(title: "Tokens / sec", value: formattedTPS,
                                systemImage: "bolt.fill",
                                accent: .orange)
                    .matchedGeometryEffect(id: "tps", in: ns)

                ForgeMetricTile(title: "Memory", value: formattedMemory,
                                systemImage: "memorychip",
                                accent: .blue)

                ForgeMetricTile(title: "Context",
                                value: contextString,
                                systemImage: "rectangle.stack",
                                accent: .indigo)

                ForgeMetricTile(title: "Tokens",
                                value: tokenCountString,
                                systemImage: "number",
                                accent: .pink)

                ForgeMetricTile(title: "First-token",
                                value: firstTokenLatencyString,
                                systemImage: "timer",
                                accent: .yellow)

                ForgeMetricTile(title: "Thermal",
                                value: store.thermalLabel,
                                systemImage: "thermometer.medium",
                                accent: thermalAccent)

                if let temp = store.snapshot.temperature {
                    ForgeMetricTile(title: "Temperature",
                                    value: String(format: "%.2f", temp),
                                    systemImage: "dial.medium",
                                    accent: .teal)
                }
                if let topP = store.snapshot.topP {
                    ForgeMetricTile(title: "top-p",
                                    value: String(format: "%.2f", topP),
                                    systemImage: "slider.horizontal.3",
                                    accent: .teal)
                }
                if let topK = store.snapshot.topK {
                    ForgeMetricTile(title: "top-k",
                                    value: "\(topK)",
                                    systemImage: "slider.horizontal.3",
                                    accent: .teal)
                }

                ForEach(store.snapshot.customMetrics) { metric in
                    ForgeMetricTile(title: metric.label,
                                    value: metric.value,
                                    systemImage: metric.systemImage,
                                    accent: .mint)
                }
            }
        }
        .padding(14)
        .forgeGlass(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Status dot

    private var statusDot: some View {
        Circle()
            .fill(store.snapshot.isGenerating ? Color.orange : Color.green)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.35), lineWidth: 0.5)
            )
            .shadow(color: store.snapshot.isGenerating ? .orange.opacity(0.6) : .clear,
                    radius: 4)
            .modifier(PulseIfActive(active: store.snapshot.isGenerating))
    }

    // MARK: - Formatters

    private var formattedTPS: String {
        guard let tps = store.snapshot.tokensPerSecond, tps > 0 else { return "—" }
        return String(format: "%.1f t/s", tps)
    }

    private var formattedMemory: String {
        let mb = store.memoryMB
        if mb >= 1024 { return String(format: "%.2f GB", mb / 1024) }
        return String(format: "%.0f MB", mb)
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

    private var thermalAccent: Color {
        switch store.thermalLabel {
        case "Nominal": return .green
        case "Fair": return .yellow
        case "Serious": return .orange
        case "Critical": return .red
        default: return .gray
        }
    }
}

private struct PulseIfActive: ViewModifier {
    let active: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && pulse ? 1.25 : 1.0)
            .opacity(active && pulse ? 0.6 : 1.0)
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
