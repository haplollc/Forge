import SwiftUI

/// Glass-style background helper that uses iOS 26's Liquid Glass when
/// available, falling back to `.ultraThinMaterial` everywhere else.
struct ForgeGlassBackground: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content.background(
                Color.black.opacity(0.35),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}

extension View {
    func forgeGlass(cornerRadius: CGFloat) -> some View {
        modifier(ForgeGlassBackground(cornerRadius: cornerRadius))
    }
}
