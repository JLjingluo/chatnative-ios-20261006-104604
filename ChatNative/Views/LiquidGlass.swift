import SwiftUI

/// Apple Liquid Glass on iOS 26+, with an explicit accessibility/older OS fallback.
struct LiquidGlassSurface: ViewModifier {
    var radius: CGFloat = 24
    var interactive = false
    var tint: Color? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(tint ?? Palette.secondary, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(interactive ? .regular.tint(tint).interactive() : .regular.tint(tint), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            } else {
                content.glassEffect(interactive ? .regular.interactive() : .regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
        } else if let tint {
            content.background(tint, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.primary.opacity(0.07), lineWidth: 0.5))
        }
    }
}

struct GlassGroup<Content: View>: View {
    var spacing: CGFloat
    let content: Content
    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    @ViewBuilder var body: some View {
        if #available(iOS 26.0, *) { GlassEffectContainer(spacing: spacing) { content } }
        else { content }
    }
}

private struct GlassIdentity: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) { content.glassEffectID(id, in: namespace) }
        else { content }
    }
}

extension View {
    func nativeGlass(radius: CGFloat = 24, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(LiquidGlassSurface(radius: radius, interactive: interactive, tint: tint))
    }
    func glassMorph(_ id: String, in namespace: Namespace.ID) -> some View { modifier(GlassIdentity(id: id, namespace: namespace)) }
}

struct GlassIconButton: View {
    let symbol: String
    let label: String
    var diameter: CGFloat = 44
    var prominent = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 19, weight: .medium))
                .foregroundStyle(prominent ? Palette.background : Palette.ink)
                .frame(width: diameter, height: diameter)
                .nativeGlass(radius: diameter / 2, interactive: true, tint: prominent ? .primary : nil)
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}
