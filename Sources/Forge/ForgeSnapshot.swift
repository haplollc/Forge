import Foundation

/// A free-form metric that surfaces in Forge's expanded panel.
public struct ForgeMetric: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let value: String
    public let systemImage: String?

    public init(id: String? = nil, label: String, value: String, systemImage: String? = nil) {
        self.id = id ?? label
        self.label = label
        self.value = value
        self.systemImage = systemImage
    }
}

/// A point-in-time view of an engine's state. Every field is optional so
/// you only fill in what you have. Forge merges its own auto-collected
/// metrics (memory, thermal, auto-TPS) on top of whatever you provide.
public struct ForgeSnapshot: Sendable {
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

    public init(
        modelName: String? = nil,
        modelArchitecture: String? = nil,
        contextUsed: Int? = nil,
        contextWindow: Int? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        firstTokenLatencyMs: Double? = nil,
        tokensPerSecond: Double? = nil,
        isGenerating: Bool = false,
        statusLabel: String? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        seed: Int? = nil,
        customMetrics: [ForgeMetric] = []
    ) {
        self.modelName = modelName
        self.modelArchitecture = modelArchitecture
        self.contextUsed = contextUsed
        self.contextWindow = contextWindow
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.firstTokenLatencyMs = firstTokenLatencyMs
        self.tokensPerSecond = tokensPerSecond
        self.isGenerating = isGenerating
        self.statusLabel = statusLabel
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.seed = seed
        self.customMetrics = customMetrics
    }

    public static let empty = ForgeSnapshot()
}
