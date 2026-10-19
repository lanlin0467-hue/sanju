import SwiftUI
import SanjuCore

enum PoetryTheme {
    static let background = Color(red: 0.94, green: 0.95, blue: 0.91)
    static func font(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("SanjuPoetry-Regular", size: size, relativeTo: style)
    }
    static func accent(_ style: WritingStyle) -> Color {
        switch style {
        case .cool: return CreationPalette.ink
        case .romantic: return Color(red: 0.62, green: 0.30, blue: 0.30)
        case .youth: return Color(red: 0.42, green: 0.43, blue: 0.22)
        }
    }
    static func paper(_ style: WritingStyle) -> Color {
        switch style {
        case .cool: return Color(red: 0.97, green: 0.97, blue: 0.92)
        case .romantic: return Color(red: 1, green: 0.94, blue: 0.90)
        case .youth: return Color(red: 0.98, green: 0.97, blue: 0.87)
        }
    }
    static func symbol(_ style: WritingStyle) -> String {
        switch style { case .cool: return "water.waves"; case .romantic: return "moon"; case .youth: return "sun.max" }
    }
    static func number(_ style: WritingStyle) -> String {
        switch style { case .cool: return "01"; case .romantic: return "02"; case .youth: return "03" }
    }
}

struct PoetryPaperBackground: View {
    var body: some View {
        GeometryReader { geometry in
            PoetryTheme.background
                .overlay(alignment: .top) {
                    Image("CreationOcean").resizable().scaledToFill()
                        .frame(width: max(0, geometry.size.width), height: 360).clipped().opacity(0.12)
                        .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct PoetrySurface<Content: View>: View {
    var color = CreationPalette.paper
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 26))
            .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(CreationPalette.ink.opacity(0.09), lineWidth: 1) }
    }
}

struct MoodLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.caption).foregroundStyle(CreationPalette.ink)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(CreationPalette.ink.opacity(0.075), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct PoetryStyleLabel: View {
    let style: WritingStyle
    var body: some View {
        Label(style.title, systemImage: PoetryTheme.symbol(style))
            .font(.subheadline.weight(.medium)).foregroundStyle(PoetryTheme.accent(style))
    }
}
