// Forge
//
// Public namespace for the Forge debugger. Hosts the shared event sink that
// providers can use to emit per-token events without having to compute
// tokens-per-second themselves.

import Foundation
#if canImport(QuartzCore)
import QuartzCore
#endif

public enum ForgeVersion {
    public static let value = "0.1.0"
}

/// Shared event sink. Use this if your engine doesn't expose a
/// `tokensPerSecond` value directly — call `tick()` once per generated token
/// and Forge will compute a rolling tokens-per-second automatically.
@MainActor
public final class Forge: ObservableObject {
    public static let shared = Forge()

    @Published public internal(set) var autoTokensPerSecond: Double = 0
    @Published public internal(set) var generatedTokens: Int = 0

    private var tickTimes: [TimeInterval] = []
    private var generationStartedAt: TimeInterval?
    private var firstTokenAt: TimeInterval?

    private init() {}

    public func beginGeneration() {
        generationStartedAt = now()
        firstTokenAt = nil
        tickTimes.removeAll(keepingCapacity: true)
        generatedTokens = 0
    }

    public func tick() {
        let t = now()
        if firstTokenAt == nil { firstTokenAt = t }
        tickTimes.append(t)
        generatedTokens &+= 1

        let cutoff = t - 2.0
        if let firstStillInWindow = tickTimes.firstIndex(where: { $0 >= cutoff }) {
            tickTimes.removeFirst(firstStillInWindow)
        }
        if let first = tickTimes.first, tickTimes.count > 1 {
            let span = max(t - first, 0.0001)
            autoTokensPerSecond = Double(tickTimes.count - 1) / span
        }
    }

    public func endGeneration() {
        // Keep `autoTokensPerSecond` visible briefly. Consumers can clear it
        // via `reset()` if they want the bar to go quiet between generations.
    }

    public func reset() {
        tickTimes.removeAll(keepingCapacity: true)
        generationStartedAt = nil
        firstTokenAt = nil
        autoTokensPerSecond = 0
        generatedTokens = 0
    }

    public var firstTokenLatencyMs: Double? {
        guard let start = generationStartedAt, let first = firstTokenAt else { return nil }
        return (first - start) * 1000
    }

    private func now() -> TimeInterval {
        #if canImport(QuartzCore)
        return CACurrentMediaTime()
        #else
        return Date().timeIntervalSince1970
        #endif
    }
}
