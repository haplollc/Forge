<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2016%2B%20%7C%20macOS%2013%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/status-early%20WIP-yellow" alt="Status">
</p>

<h1 align="center">🔥 Forge</h1>

<p align="center">
  <strong>A floating SwiftUI overlay debugger for local LLMs.</strong><br>
  <em>Every token, sampler step, grammar mask, and tool call — live, inside your dev build.</em>
</p>

<p align="center">
  Inspect • Replay • Branch • Export
</p>

---

Forge is the devtool every Swift engineer building on a local LLM has been hand-rolling. Drop it into your dev target and a draggable floating overlay appears in your running iOS or Mac app. It shows — in real time, while your model thinks:

- Every prompt and every system message, with token counts
- Every token as it's sampled, with logits and the chosen sampler chain
- Every grammar-masked step (when using GBNF / structured decoding)
- Every tool call, retry, and validation pass
- Per-turn latency, tokens/sec, and memory usage

You can pause mid-generation, branch from any token with different sampler params, and export the whole trace as JSON for offline analysis.

## Why this is novel

Cloud LLM dev has Langfuse, Arize, OpenTelemetry. Local Swift LLM dev has `print()`. Forge is the first observability tool designed *for* on-device inference: it lives inside the running app, has no network dependency, and understands the primitives of llama.cpp / Kuzco (samplers, grammars, tool grammars) at a structural level.

## Planned features

| Category | Capabilities |
|----------|-------------|
| 🪟 **Floating overlay** | Draggable, resizable SwiftUI HUD that runs inside your dev app |
| 🔬 **Token inspector** | See logits, top-k, sampler chain, and chosen token per step |
| 🧱 **Grammar view** | Visualize GBNF state and which tokens were masked at each step |
| 🛠️ **Tool-call trace** | See every model-emitted tool call, the executor's response, and any retries |
| ⏪ **Branch &amp; replay** | Pause mid-stream, fork from any token with different params, compare outputs |
| 📈 **Live metrics** | Tokens/sec, latency, KV-cache size, memory pressure, thermal state |
| 📤 **Export** | JSON / .traceforge bundles you can open later or share for repro |
| 🤝 **Kuzco-native** | Zero-config when used with a [Kuzco](https://github.com/haplollc/Kuzco) session |

## Planned API (subject to change)

```swift
import Forge
import Kuzco

#if DEBUG
ForgeOverlay.attach(to: kuzcoEngine)   // floating HUD now visible
#endif

// Or scoped to a single window:
WindowGroup {
    ContentView()
        .forgeOverlay()                // SwiftUI modifier variant
}
```

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/haplollc/Forge.git", from: "0.1.0")
]
```

## Status

🚧 **Early WIP.** Floating overlay + token inspector are the first targets.

## License

MIT © [Haplo LLC](https://haplo.ai)
