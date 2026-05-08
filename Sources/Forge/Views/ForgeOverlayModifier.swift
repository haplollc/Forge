import SwiftUI

/// A drop-in `ForgeBar` view designed to be placed directly above a chat
/// input bar (or anywhere else you'd like a debugger HUD to live). The
/// collapsed state matches the dimensions of an empty single-row input
/// bar; tap it and the panel grows in place with animated graphs.
public struct ForgeBar: View {
    private weak var provider: ForgeProvider?
    private let isEnabled: Bool
    private let refreshHz: Double

    public init(provider: ForgeProvider?, isEnabled: Bool = true, refreshHz: Double = 4) {
        self.provider = provider
        self.isEnabled = isEnabled
        self.refreshHz = refreshHz
    }

    public var body: some View {
        Group {
            if isEnabled, let provider {
                ForgeOverlay(provider: provider, refreshHz: refreshHz)
                    .padding(.horizontal)
                    .transition(
                        .move(edge: .bottom).combined(with: .opacity)
                    )
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isEnabled)
    }
}

/// Convenience modifier: pin a `ForgeBar` to the bottom safe-area inset of a
/// view. Use this if you don't want to embed `ForgeBar` manually.
public struct ForgeOverlayModifier: ViewModifier {
    private weak var provider: ForgeProvider?
    private let isEnabled: Bool
    private let refreshHz: Double

    public init(provider: ForgeProvider?, isEnabled: Bool, refreshHz: Double) {
        self.provider = provider
        self.isEnabled = isEnabled
        self.refreshHz = refreshHz
    }

    public func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 8) {
            ForgeBar(provider: provider, isEnabled: isEnabled, refreshHz: refreshHz)
        }
    }
}

public extension View {
    /// Convenience: pin a Forge debugger bar above the bottom safe-area
    /// inset of this view. For finer placement, embed `ForgeBar` directly
    /// (e.g. as a sibling above your own chat input bar).
    func forgeOverlay(
        provider: ForgeProvider?,
        isEnabled: Bool = true,
        refreshHz: Double = 4
    ) -> some View {
        modifier(ForgeOverlayModifier(
            provider: provider,
            isEnabled: isEnabled,
            refreshHz: refreshHz
        ))
    }
}
