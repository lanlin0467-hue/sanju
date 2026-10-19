import SwiftUI
import SanjuCore

enum SanjuTheme {
    static let accent = Color("AccentColor")
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let radius: CGFloat = 22
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(18).background(SanjuTheme.surface, in: RoundedRectangle(cornerRadius: SanjuTheme.radius)) }
}

struct PrimaryButton: View {
    let title: String
    var busy = false
    var disabled = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { if busy { ProgressView().tint(.white) }; Text(title).fontWeight(.semibold) }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        .buttonBorderShape(.roundedRectangle(radius: 17)).disabled(disabled)
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
            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
    }
}
