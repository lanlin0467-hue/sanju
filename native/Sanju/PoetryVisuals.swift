import SwiftUI
import SanjuCore

enum PoetryTheme {
    static func font(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("SanjuPoetry-Regular", size: size, relativeTo: style)
    }
    // Presentation only: copying, sharing and searching always use the original text.
    static func readingText(_ text: String) -> String {
        guard !text.contains("\n") else { return text }
        let characters = Array(text)
        let candidates = characters.indices.filter { (characters[$0] == "，" || characters[$0] == "、") && $0 >= 5 && $0 < characters.count - 5 }
        guard let split = candidates.min(by: { abs($0 - characters.count / 2) < abs($1 - characters.count / 2) }) else { return text }
        return String(characters[...split]) + "\n" + String(characters[(split + 1)...])
    }
}

struct SentenceText: View {
    let text: String
    var size: CGFloat = 20
    var relativeTo: Font.TextStyle = .title3
    var body: some View {
        Text(PoetryTheme.readingText(text)).font(PoetryTheme.font(size, relativeTo: relativeTo))
            .lineSpacing(size * 0.3).foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            .accessibilityLabel(text)
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String = ""
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { Text(title); Spacer(minLength: 8); Text(detail) }
            VStack(alignment: .leading, spacing: 4) { Text(title); if !detail.isEmpty { Text(detail) } }
        }.font(.footnote).foregroundStyle(SanjuTheme.secondaryText).padding(.horizontal, 16)
    }
}

struct MoodLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote.weight(.semibold)).foregroundStyle(SanjuTheme.accent)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(SanjuTheme.tintSoft, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ContextSummary: View {
    let input: CreationInput
    let date: Date
    var body: some View {
        Surface {
            HStack(spacing: 12) {
                InputThumbnail(input: input, size: 48)
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { MoodLabel(text: input.mood); timestamp }
                        VStack(alignment: .leading, spacing: 4) { MoodLabel(text: input.mood); timestamp }
                    }
                    Text(input.summary).font(.subheadline).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
    private var timestamp: some View {
        Text(date.formatted(.dateTime.month().day().hour().minute())).font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
    }
}

struct InputThumbnail: View {
    let input: CreationInput
    var size: CGFloat = 52
    var body: some View {
        Group {
            if let data = input.imageData { PreparedPhoto(data: data, maxPixelSize: 240, contentMode: .fill) }
            else { Image(systemName: "text.quote").font(.title2).foregroundStyle(SanjuTheme.secondaryText).frame(maxWidth: .infinity, maxHeight: .infinity).background(SanjuTheme.fill) }
        }.frame(width: size, height: size).clipped().clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)).accessibilityHidden(true)
    }
}

struct FavoriteButton: View {
    let line: SentenceVersion
    var disabled = false
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var selected: Bool { line.favoritedAt != nil }
    var body: some View {
        Button(action: action) {
            Image(systemName: selected ? "star.fill" : "star").font(.system(size: 20))
                .foregroundStyle(selected ? SanjuTheme.favorite : SanjuTheme.secondaryText)
                .frame(width: 44, height: 44)
                .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : selected)
        }.buttonStyle(.plain).disabled(disabled)
            .accessibilityLabel((selected ? "取消收藏" : "收藏") + line.style.title + "这句")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .sensoryFeedback(.impact(weight: .light), trigger: selected)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(SanjuTheme.accent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(SanjuTheme.tintSoft, in: Capsule()).opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct MoodFlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(width: proposal.width ?? 350, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(width: bounds.width, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: ProposedViewSize(width: result.widths[index], height: nil))
        }
    }
    private func layout(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint], widths: [CGFloat]) {
        let width = width.isFinite && width >= 44 ? width : 350
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var points: [CGPoint] = [], widths: [CGFloat] = []
        for view in subviews {
            let ideal = view.sizeThatFits(.unspecified)
            let itemWidth = min(ideal.width, width)
            let size = view.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            if x > 0 && x + itemWidth > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y)); widths.append(itemWidth)
            x += itemWidth + spacing; rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points, widths)
    }
}

extension Creation {
    var deletionMessage: String {
        let currentCount = WritingStyle.allCases.compactMap { current($0) }.count
        return "将一起删除：照片与画面描述、\(currentCount) 句当前句子、\(max(0, versions.count - currentCount)) 句旧句，其中 \(favoriteCount) 条收藏。句库只保存在本机，删除后无法恢复。"
    }
}
