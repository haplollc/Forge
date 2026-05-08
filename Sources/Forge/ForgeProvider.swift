import Foundation

/// The single point of contact between Forge and your AI stack.
///
/// Conform whichever object owns your local-LLM state to `ForgeProvider`,
/// then return a `ForgeSnapshot` describing the current model, generation
/// phase, and any metrics you'd like Forge to surface.
///
/// All fields on `ForgeSnapshot` are optional — return what you have, and
/// Forge will fill in the rest (memory usage, thermal state, auto-computed
/// tokens-per-second from `Forge.shared.tick()`).
public protocol ForgeProvider: AnyObject {
    /// A snapshot of the engine's current state. Forge polls this at the
    /// refresh rate you pass to `.forgeOverlay(...)` (default 4 Hz).
    @MainActor var forgeSnapshot: ForgeSnapshot { get }
}
