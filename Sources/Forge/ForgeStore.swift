import Foundation
import Combine

/// Internal observable that drives Forge's UI. Combines the provider's
/// snapshot with auto-collected metrics (memory, thermal, auto-TPS) and
/// retains rolling history buffers so charts have data to render.
@MainActor
final class ForgeStore: ObservableObject {
    static let historyCapacity = 60   // ~15 s of samples at 4 Hz

    @Published var snapshot: ForgeSnapshot = .empty
    @Published var memoryMB: Double = 0
    @Published var thermalLabel: String = "Nominal"

    @Published var tpsHistory: [Sample] = []
    @Published var memoryHistory: [Sample] = []

    struct Sample: Identifiable, Equatable {
        let id: Int
        let value: Double
    }

    private var sampleCounter: Int = 0
    private weak var provider: ForgeProvider?
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    func attach(provider: ForgeProvider, refreshHz: Double) {
        self.provider = provider
        timer?.invalidate()
        let interval = 1.0 / max(refreshHz, 0.5)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        poll()

        Forge.shared.$autoTokensPerSecond
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.poll() }
            .store(in: &cancellables)
    }

    func detach() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
        provider = nil
    }

    private func poll() {
        guard let provider else { return }
        var snap = provider.forgeSnapshot

        if snap.tokensPerSecond == nil, Forge.shared.autoTokensPerSecond > 0 {
            snap.tokensPerSecond = Forge.shared.autoTokensPerSecond
        }
        if snap.completionTokens == nil, Forge.shared.generatedTokens > 0 {
            snap.completionTokens = Forge.shared.generatedTokens
        }
        if snap.firstTokenLatencyMs == nil {
            snap.firstTokenLatencyMs = Forge.shared.firstTokenLatencyMs
        }

        let memory = ForgeMetricsProbe.memoryUsageMB()

        self.snapshot = snap
        self.memoryMB = memory
        self.thermalLabel = ForgeMetricsProbe.thermalLabel()

        sampleCounter &+= 1
        appendSample(&tpsHistory, value: snap.tokensPerSecond ?? 0)
        appendSample(&memoryHistory, value: memory)
    }

    private func appendSample(_ buffer: inout [Sample], value: Double) {
        buffer.append(Sample(id: sampleCounter, value: value))
        if buffer.count > Self.historyCapacity {
            buffer.removeFirst(buffer.count - Self.historyCapacity)
        }
    }
}
