<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017%2B%20%7C%20macOS%2014%2B%20%7C%20visionOS%201%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-Native-purple" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

<h1 align="center">🔥 Forge</h1>

<p align="center">
  <strong>A floating SwiftUI overlay debugger for local LLMs.</strong><br>
  <em>Inspect your on-device model in real time — tokens/sec, memory, context use, and more —<br>
  with one view modifier and a single-property protocol.</em>
</p>

<p align="center">
  Plug-and-play • Engine-agnostic • Glass-styled • Animated bar ↔ panel
</p>

---

## Why Forge

Cloud LLMs have Langfuse, Arize, OpenTelemetry. Local Swift LLMs have `print()`. Forge is the floating debugger you've been hand-rolling: drop one modifier on your chat view, conform your AI manager to one protocol, and a glassy collapsible HUD pins itself to the top of your screen with live metrics from whatever inference stack you use — Kuzco, llama.cpp, MLX, Apple Foundation Models, your own.

Tap the bar to expand into a full metric panel. Tap the glass `xmark` to collapse. The transition is matched-geometry spring-y, the dot pulses while the model thinks, and Forge auto-fills memory, thermal state, and tokens-per-second so you don't have to.

## Highlights

| Feature | Notes |
|---|---|
| 🪄 **One modifier** | `.forgeOverlay(provider:isEnabled:)` is the entire UI surface |
| 🔌 **One-property protocol** | Conform `ForgeProvider` and return a `ForgeSnapshot` |
| 🧪 **Engine-agnostic** | Works with Kuzco, llama.cpp wrappers, MLX, Apple Foundation Models, anything |
| ✨ **Animated bar ↔ panel** | Spring transitions, matched-geometry, pulsing status dot, glassy materials |
| 🪟 **Floating, non-intrusive** | Pins under your nav/toolbar via `.overlay(alignment: .top)` — never displaces layout |
| 📊 **Auto-collected metrics** | Memory (resident MB), thermal state, auto-TPS via `Forge.shared.tick()` |
| 🛠️ **Custom metrics** | Add app-specific tiles with `ForgeMetric(label:value:systemImage:)` |
| 🚦 **Toggle-friendly** | `isEnabled:` parameter wires cleanly to a `@AppStorage` dev-mode flag |

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/haplollc/Forge.git", from: "0.1.0")
]
```

**Or in Xcode:** File → Add Package Dependencies → `https://github.com/haplollc/Forge.git`

## Quickstart

### 1. Conform your AI manager to `ForgeProvider`

The protocol has exactly one requirement: a `forgeSnapshot` computed property. Return whatever you have — every field on `ForgeSnapshot` is optional, and Forge fills in the rest itself.

```swift
import Forge

extension MyChatService: ForgeProvider {
    @MainActor
    var forgeSnapshot: ForgeSnapshot {
        ForgeSnapshot(
            modelName: engine.currentModel?.name,
            modelArchitecture: engine.currentModel?.architecture,    // e.g. "llama"
            contextUsed: engine.usedContextTokens,
            contextWindow: engine.contextWindowSize,
            promptTokens: engine.lastPromptTokenCount,
            completionTokens: engine.lastCompletionTokenCount,
            isGenerating: engine.isStreaming,
            statusLabel: engine.isStreaming ? "Streaming" : "Idle",
            temperature: engine.temperature,
            topP: engine.topP,
            topK: engine.topK,
            customMetrics: [
                ForgeMetric(label: "Backend",  value: "Metal", systemImage: "cpu"),
                ForgeMetric(label: "Quant",    value: "Q4_K_M", systemImage: "square.stack.3d.up")
            ]
        )
    }
}
```

### 2. Place the bar above your chat input

The cleanest pattern is to embed `ForgeBar` as a sibling above your input bar — the collapsed state is sized to match an empty single-row input, and the expanded panel grows in place above it.

```swift
import Forge

struct ChatView: View {
    @StateObject private var chatService = MyChatService()
    @AppStorage("forgeOverlayEnabled") private var forgeOverlayEnabled = false

    var body: some View {
        VStack { /* …your messages list… */ }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    ForgeBar(provider: chatService, isEnabled: forgeOverlayEnabled)
                    ChatInputBar(...)
                }
            }
    }
}
```

Don't have a custom safe-area inset? Use the convenience modifier — it pins a `ForgeBar` to the bottom for you:

```swift
ChatView()
    .forgeOverlay(provider: chatService, isEnabled: forgeOverlayEnabled)
```

Tap the bar to expand. Tap the glass `xmark` (top-left) to collapse.

### 3. (Optional) Let Forge compute tokens/sec for you

If your engine doesn't expose a live `tokensPerSecond`, hand Forge per-token events and it'll compute a rolling 2-second TPS automatically:

```swift
Forge.shared.beginGeneration()
for try await chunk in engine.stream(prompt: prompt) {
    Forge.shared.tick()
    // …append chunk to your message…
}
Forge.shared.endGeneration()
```

`Forge.shared.firstTokenLatencyMs` is also available after the first tick fires.

## What you get in the HUD

### Collapsed (bar)
```
┌────────────────────────────────────────────┐
│  ●  Llama-3.2-3B-Instruct.Q4_K_M    ⚡ 24.3 t/s   📊 1.2 GB │
└────────────────────────────────────────────┘
```
Status dot (pulses when generating) · model name (truncated middle) · live TPS · resident memory.

### Expanded (panel)
- Glass `xmark` circle button (top-left, animates in from scale + opacity)
- Model name + architecture + status label
- **Live animated graphs** (Swift Charts, Catmull-Rom interpolation, monochrome white-on-glass):
  - Tokens / sec sparkline with pulsing tip indicator
  - Memory sparkline
  - Context fill bar (only shown when both `contextUsed` and `contextWindow` are provided)
- Metric tiles (2-column grid): first-token latency, token counts, thermal state, refresh rate, plus any `customMetrics` you supply
- Sampler param chips (temperature / top-p / top-k) — only shown when provided

## API surface

### `ForgeProvider`
```swift
public protocol ForgeProvider: AnyObject {
    @MainActor var forgeSnapshot: ForgeSnapshot { get }
}
```

### `ForgeSnapshot`
A free-form struct. Every field is optional except `isGenerating`. Construct it however your engine exposes data.

```swift
public struct ForgeSnapshot {
    public var modelName: String?
    public var modelArchitecture: String?
    public var contextUsed: Int?
    public var contextWindow: Int?
    public var promptTokens: Int?
    public var completionTokens: Int?
    public var firstTokenLatencyMs: Double?
    public var tokensPerSecond: Double?
    public var isGenerating: Bool
    public var statusLabel: String?
    public var temperature: Double?
    public var topP: Double?
    public var topK: Int?
    public var seed: Int?
    public var customMetrics: [ForgeMetric]
}
```

### `ForgeMetric`
```swift
ForgeMetric(label: "Backend", value: "Metal", systemImage: "cpu")
```

### `Forge.shared`
```swift
@MainActor public final class Forge: ObservableObject {
    public static let shared: Forge

    public func beginGeneration()       // call when streaming starts
    public func tick()                  // call once per token
    public func endGeneration()         // call when streaming ends
    public func reset()                 // clear all rolling counters

    public var firstTokenLatencyMs: Double?
    public var autoTokensPerSecond: Double
    public var generatedTokens: Int
}
```

### `ForgeBar` (recommended)
```swift
public struct ForgeBar: View {
    public init(provider: ForgeProvider?, isEnabled: Bool = true, refreshHz: Double = 4)
}
```
Embed directly as a sibling above your chat input bar.

### `.forgeOverlay(...)` (convenience)
```swift
extension View {
    func forgeOverlay(
        provider: ForgeProvider?,
        isEnabled: Bool = true,
        refreshHz: Double = 4
    ) -> some View
}
```
Pins a `ForgeBar` to the bottom safe-area inset. Use it when you don't already have a custom bottom inset and just want a one-liner.

`refreshHz` controls how often Forge polls your `forgeSnapshot`. The default of 4 Hz is plenty for a debugger and trivially cheap.

## What's included

```
Sources/Forge/
├── Forge.swift                  // Shared event sink (begin / tick / end)
├── ForgeProvider.swift          // The plug-and-play protocol
├── ForgeSnapshot.swift          // Snapshot + ForgeMetric types
├── ForgeStore.swift             // Observable + rolling history buffers for charts
├── ForgeMetricsProbe.swift      // Memory & thermal probes
└── Views/
    ├── ForgeOverlay.swift       // Collapsed bar + expanded panel
    ├── ForgeOverlayModifier.swift  // ForgeBar view + .forgeOverlay() modifier
    ├── ForgeChart.swift         // Animated sparklines + context-fill bar
    ├── ForgeMetricTile.swift    // One tile in the expanded grid (monochrome)
    ├── ForgeGlassButton.swift   // The xmark glass button
    └── ForgeBackport.swift      // Glass-style background helper
```

Tests live under `Tests/ForgeTests/`. CI runs on a self-hosted macOS runner; both `swift build` and an iOS Simulator build are exercised.

## Patterns

### Gate it behind a setting
```swift
@AppStorage("forgeOverlayEnabled") private var forgeOverlayEnabled = false

// In Settings:
Toggle("Forge Debugger Overlay", isOn: $forgeOverlayEnabled)

// In your chat view:
.forgeOverlay(provider: aiManager, isEnabled: forgeOverlayEnabled)
```

### Tie status text to a generation phase enum
```swift
var forgeSnapshot: ForgeSnapshot {
    let label: String = switch engine.phase {
        case .idle: "Idle"
        case .loadingModel: "Loading model…"
        case .thinking: "Thinking…"
        case .streaming: "Streaming"
    }
    return ForgeSnapshot(
        modelName: engine.modelName,
        isGenerating: engine.phase != .idle,
        statusLabel: label
    )
}
```

### DEBUG-only attachment
```swift
ChatView()
#if DEBUG
    .forgeOverlay(provider: aiManager)
#endif
```

## Roadmap

- 🧱 **Grammar inspector** — visualize GBNF state and which tokens were masked
- 🔬 **Token logit panel** — see top-k logits and the chosen token per step
- 🛠️ **Tool-call trace** — surface model-emitted tool calls and executor responses
- ⏪ **Branch & replay** — fork a generation from any token with different params
- 📤 **Export** — JSON / `.traceforge` bundles for offline inspection

## License

MIT © [Haplo LLC](https://haplo.ai)
