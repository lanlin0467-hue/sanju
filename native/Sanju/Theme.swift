import SwiftUI
import SanjuCore

enum SanjuTheme {
    static let accent = Color("AccentColor")
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let secondaryText = Color("SecondaryText")
    static let tintSoft = Color("TintSoft")
    static let favorite = Color("Favorite")
    static let destructive = Color("Destructive")
    static let fill = Color(uiColor: .tertiarySystemFill)
    static let radius: CGFloat = 22
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(SanjuTheme.surface, in: RoundedRectangle(cornerRadius: SanjuTheme.radius, style: .continuous)) }
}

struct PrimaryButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var busy = false
    var disabled = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { if busy { ProgressView().tint(colorScheme == .dark ? .black : .white) }; Text(title).fontWeight(.semibold) }
                .foregroundStyle(disabled ? SanjuTheme.secondaryText : colorScheme == .dark ? .black : .white)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).disabled(disabled)
    }
}

struct PhotoPreview: View {
    let data: Data
    var height: CGFloat = 200
    var body: some View {
        PreparedPhoto(data: data, maxPixelSize: 1280, contentMode: .fit)
            .frame(maxWidth: .infinity).frame(height: height)
            .background(SanjuTheme.surface).clipShape(RoundedRectangle(cornerRadius: SanjuTheme.radius))
            .accessibilityLabel("所选照片")
    }
}

struct DemoBadge: View {
    var body: some View {
        Label("示例体验 · 固定文案，不调用 AI", systemImage: "sparkle")
            .font(.caption).foregroundStyle(SanjuTheme.secondaryText).padding(.vertical, 4)
    }
}
