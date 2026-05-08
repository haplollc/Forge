import SwiftUI

/// View modifier that pins a `ForgeOverlay` to the top of the modified view.
/// Apply on the content area of your screen — the modifier inserts the
/// overlay using SwiftUI's `.overlay(alignment: .top)` so it floats *above*
/// your content without affecting layout.
public struct ForgeOverlayModifier: ViewModifier {
    private weak var provider: ForgeProvider?
    private let isEnabled: Bool
    private let refreshHz: Double
    private let topInset: CGFloat
    private let horizontalInset: CGFloat

    public init(
        provider: ForgeProvider?,
        isEnabled: Bool,
        refreshHz: Double,
        topInset: CGFloat,
        horizontalInset: CGFloat
    ) {
        self.provider = provider
        self.isEnabled = isEnabled
        self.refreshHz = refreshHz
        self.topInset = topInset
        self.horizontalInset = horizontalInset
    }

    public func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if isEnabled, let provider {
                ForgeOverlay(provider: provider, refreshHz: refreshHz)
                    .padding(.top, topInset)
                    .padding(.horizontal, horizontalInset)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isEnabled)
                    .allowsHitTesting(true)
            }
        }
    }
}

public extension View {
    /// Pin a Forge overlay to the top of this view.
    ///
    /// - Parameters:
    ///   - provider: An object that conforms to `ForgeProvider`.
    ///   - isEnabled: Toggle to show/hide. Bind to a settings flag so users
    ///     can enable Forge only in dev or only on demand. Defaults to `true`.
    ///   - refreshHz: How often Forge polls the provider. Default `4`.
    ///   - topInset: Padding from the top edge. Default `4`.
    ///   - horizontalInset: Side padding. Default `12`.
    func forgeOverlay(
        provider: ForgeProvider?,
        isEnabled: Bool = true,
        refreshHz: Double = 4,
        topInset: CGFloat = 4,
        horizontalInset: CGFloat = 12
    ) -> some View {
        modifier(ForgeOverlayModifier(
            provider: provider,
            isEnabled: isEnabled,
            refreshHz: refreshHz,
            topInset: topInset,
            horizontalInset: horizontalInset
        ))
    }
}
