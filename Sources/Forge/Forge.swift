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
/// `tokensPerSecond` value directly — call `tick()` once per token (or
/// `tick(tokens: n)` if a single chunk represents multiple tokens) and
/// Forge will compute a rolling tokens-per-second automatically.
@MainActor
public final class Forge: ObservableObject {
    public static let shared = Forge()

    /// Length of the rolling window used to compute `autoTokensPerSecond`.
    /// Short enough to feel live, long enough to smooth out per-batch jitter.
    public static let rollingWindowSeconds: Double = 1.5

    /// Heuristic for estimating tokens from a chunk of generated text when
    /// the engine doesn't report token counts directly. Roughly matches BPE
    /// tokenizers (Llama / Apple Foundation Models / GPT-class).
    public static func estimateTokens(in text: String) -> Int {
        let chars = text.unicodeScalars.count
        guard chars > 0 else { return 0 }
        // ~4 chars / token is the canonical rule of thumb. Round up so a
        // very short chunk still counts as ≥1 token.
        return max(1, Int((Double(chars) / 4.0).rounded(.up)))
    }

    @Published public internal(set) var autoTokensPerSecond: Double = 0
    @Published public internal(set) var generatedTokens: Int = 0

    private struct TickEntry {
        let at: TimeInterval
        let tokens: Int
    }

    private var tickEntries: [TickEntry] = []
    private var generationStartedAt: TimeInterval?
    private var firstTokenAt: TimeInterval?
    private var lastTickAt: TimeInterval?

    private init() {}

    public func beginGeneration() {
        generationStartedAt = now()
        firstTokenAt = nil
        lastTickAt = nil
        tickEntries.removeAll(keepingCapacity: true)
        generatedTokens = 0
        autoTokensPerSecond = 0
    }

    /// Record one or more tokens as having been generated *now*.
    ///
    /// - Parameter tokens: how many tokens this tick represents. Defaults
    ///   to `1` for engines that emit a single token per stream chunk
    ///   (most llama.cpp wrappers). Pass a larger value when a single
    ///   stream event yields multiple tokens (e.g. Apple Foundation
    ///   Models snapshot deltas) — `Forge.estimateTokens(in:)` is a
    ///   reasonable default if you only have the text.
    public func tick(tokens: Int = 1) {
        guard tokens > 0 else { return }
        let t = now()
        if firstTokenAt == nil { firstTokenAt = t }
        lastTickAt = t

        tickEntries.append(TickEntry(at: t, tokens: tokens))
        generatedTokens &+= tokens

        evictOldEntries(now: t)
        recomputeRate(now: t)
    }

    public func endGeneration() {
        // Keep `autoTokensPerSecond` visible briefly after streaming ends
        // (so the panel doesn't blink to zero on a quick read), but let
        // the staleness check naturally drift it back to 0 if no new
        // tokens arrive.
    }

    public func reset() {
        tickEntries.removeAll(keepingCapacity: true)
        generationStartedAt = nil
        firstTokenAt = nil
        lastTickAt = nil
        autoTokensPerSecond = 0
        generatedTokens = 0
    }

    public var firstTokenLatencyMs: Double? {
        guard let start = generationStartedAt, let first = firstTokenAt else { return nil }
        return (first - start) * 1000
    }

    /// Periodically called from the Forge polling loop so the rate decays
    /// to zero when streaming stops, instead of getting stuck at the last
    /// computed value.
    func decayIfStale(now t: TimeInterval = CACurrentMediaTime()) {
        guard let last = lastTickAt else {
            autoTokensPerSecond = 0
            return
        }
        if t - last > Self.rollingWindowSeconds {
            evictOldEntries(now: t)
            recomputeRate(now: t)
        }
    }

    // MARK: - Internals

    private func evictOldEntries(now t: TimeInterval) {
        let cutoff = t - Self.rollingWindowSeconds
        while let first = tickEntries.first, first.at < cutoff {
            tickEntries.removeFirst()
        }
    }

    private func recomputeRate(now t: TimeInterval) {
        // Need at least 2 entries inside the window to define a rate.
        guard tickEntries.count >= 2,
              let firstEntry = tickEntries.first
        else {
            autoTokensPerSecond = 0
            return
        }

        // Tokens emitted *after* the first observed entry, divided by the
        // span between the first and the most recent. This avoids
        // double-counting the first batch (which arrived "instantly" at
        // the start of our window).
        let tokensInWindow = tickEntries.dropFirst().reduce(0) { $0 + $1.tokens }
        let span = max(t - firstEntry.at, 0.0001)
        autoTokensPerSecond = Double(tokensInWindow) / span
    }

    private func now() -> TimeInterval {
        #if canImport(QuartzCore)
        return CACurrentMediaTime()
        #else
        return Date().timeIntervalSince1970
        #endif
    }
}
