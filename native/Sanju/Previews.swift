#if DEBUG
import SwiftUI
import SanjuCore

private struct PreviewPersistence: LibraryPersistence {
    func load() throws -> LibraryState {
        var state = LibraryState()
        state.draft = CreationInput(scene: "黄昏的海边，风很轻", mood: "平静")
        state.quota = .demo(now: Date())
        var lines = WritingStyle.allCases.map { SentenceVersion(style: $0, text: DemoGenerationService.samples[$0]![0]) }
        lines[0].favoritedAt = Date()
        state.records = [Creation(id: PreviewData.id, input: state.draft, createdAt: Date(), expiresAt: Date().addingTimeInterval(86400), swapsRemaining: 3, versions: lines, isDemo: true)]
        return state
    }
    func save(_ state: LibraryState) throws {}
}
private enum PreviewData {
    static let id = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
}
private struct PreviewHost<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var store: AppStore?
    var body: some View {
        Group { if let store { content.environment(store).tint(SanjuTheme.accent) } else { ProgressView() } }
            .task { if store == nil { store = await AppStore(persistence: PreviewPersistence(), service: DemoGenerationService()) } }
    }
}
#Preview("创作") { PreviewHost { AppRootView() } }
#Preview("生成结果") { PreviewHost { NavigationStack { ResultView(creationID: PreviewData.id, editInput: {}) } } }
#Preview("句库") { PreviewHost { NavigationStack { LibraryView(startCreation: {}, editInput: { _ in }) } } }
#endif
