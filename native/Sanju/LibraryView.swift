import SwiftUI
import SanjuCore

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    var startCreation: () -> Void
    var editInput: (UUID) -> Void
    @State private var onlyFavorites = false
    @State private var query = ""
    @State private var deleting: Creation?
    @State private var selectedFavorite: FavoriteReference?
    private var searchText: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var records: [Creation] { store.records.filter { $0.matches(searchText) } }
    private var favoriteCount: Int { store.records.reduce(0) { $0 + $1.favoriteCount } }
    private var favorites: [FavoriteReference] {
        store.records.flatMap { record in
            record.versions.filter { $0.favoritedAt != nil && (searchText.isEmpty || $0.text.localizedStandardContains(searchText) || record.input.scene.localizedStandardContains(searchText) || record.input.mood.localizedStandardContains(searchText)) }
                .map { FavoriteReference(creation: record, line: $0) }
        }.sorted { ($0.line.favoritedAt ?? .distantPast) > ($1.line.favoritedAt ?? .distantPast) }
    }

    var body: some View {
        List {
            introduction
                .listRowInsets(EdgeInsets(top: 18, leading: 22, bottom: 18, trailing: 22))
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
            Picker("句库范围", selection: $onlyFavorites) { Text("全部").tag(false); Text("收藏").tag(true) }
                .pickerStyle(.segmented).tint(CreationPalette.ink)
                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 14, trailing: 22))
            if !searchText.isEmpty {
                Text("找到 \(onlyFavorites ? favorites.count : records.count) \(onlyFavorites ? "句收藏" : "份创作")")
                    .font(.caption).foregroundStyle(CreationPalette.mutedInk)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 24, bottom: 6, trailing: 22))
            }
            if onlyFavorites {
                if favorites.isEmpty { emptyView }
                ForEach(favorites) { item in
                    Button { selectedFavorite = item } label: {
                        sentenceRow(item.line, record: item.creation, favorite: true)
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("libraryFavorite_" + item.id.uuidString)
                    .listRowInsets(rowInsets).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .swipeActions {
                        Button("取消收藏", systemImage: "bookmark.slash") { Task { await store.toggleFavorite(creationID: item.creation.id, sentenceID: item.line.id) } }
                            .tint(PoetryTheme.accent(.romantic))
                    }
                }
            } else {
                if records.isEmpty { emptyView }
                ForEach(records) { record in
                    NavigationLink {
                        ResultView(creationID: record.id) { editInput(record.id) }
                    } label: { sentenceRow(preview(record), record: record, favorite: false) }
                    .accessibilityIdentifier("libraryRecord_" + record.id.uuidString)
                    .listRowInsets(rowInsets).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .swipeActions { Button("删除", systemImage: "trash", role: .destructive) { deleting = record } }
                    .contextMenu { Button("删除记录", systemImage: "trash", role: .destructive) { deleting = record } }
                }
            }
            if !(onlyFavorites ? favorites.isEmpty : records.isEmpty) {
                Text(onlyFavorites ? "喜欢的句子，值得再读一遍。" : "每一次创作，都在这里慢慢积成光。")
                    .font(.caption).foregroundStyle(CreationPalette.mutedInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).scrollDismissesKeyboard(.interactively)
        .background { PoetryPaperBackground() }
        .foregroundStyle(CreationPalette.ink).tint(CreationPalette.ink)
        .navigationTitle("句库").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PoetryTheme.background, for: .navigationBar).toolbarColorScheme(.light, for: .navigationBar)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索句子、画面或心情")
        .confirmationDialog("删除这份创作？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除记录", role: .destructive) { if let deleting { Task { await store.delete(deleting.id) } }; deleting = nil }
        } message: {
            Text("将删除配图和所有句子版本\((deleting?.favoriteCount ?? 0) > 0 ? "，同时删除其中的 \(deleting?.favoriteCount ?? 0) 条收藏" : "")。此操作不可恢复。")
        }
        .sheet(item: $selectedFavorite) { item in
            FavoriteDetailView(creationID: item.creation.id, sentenceID: item.line.id, editInput: editInput)
        }
    }

    private var rowInsets: EdgeInsets { EdgeInsets(top: 6, leading: 22, bottom: 6, trailing: 22) }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("收好每一次心动。")
                .font(PoetryTheme.font(30, relativeTo: .largeTitle)).foregroundStyle(CreationPalette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("让那些说中你的话，有处可回。")
                .font(.subheadline).foregroundStyle(CreationPalette.mutedInk)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { statistics }
                VStack(alignment: .leading, spacing: 8) { statistics }
            }.font(.caption).foregroundStyle(CreationPalette.mutedInk).padding(.top, 4)
        }
    }
    @ViewBuilder private var statistics: some View {
        Label("\(store.records.count) 份创作", systemImage: "text.quote")
        Label("\(favoriteCount) 句收藏", systemImage: "bookmark")
    }
    private func preview(_ record: Creation) -> SentenceVersion? {
        if !searchText.isEmpty, let match = record.versions.reversed().first(where: { $0.text.localizedStandardContains(searchText) }) { return match }
        return record.current(.cool) ?? record.versions.first
    }
    private func sentenceRow(_ line: SentenceVersion?, record: Creation, favorite: Bool) -> some View {
        let style = line?.style ?? .cool
        let oldVersion = line.map { record.current($0.style)?.id != $0.id } ?? false
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PoetryStyleLabel(style: style)
                Spacer(minLength: 0)
                if favorite { Image(systemName: "bookmark.fill").foregroundStyle(PoetryTheme.accent(style)).accessibilityHidden(true) }
                else { Text(record.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(CreationPalette.mutedInk) }
            }
            HStack(alignment: .top, spacing: 14) {
                Text(line?.text ?? record.input.summary).font(PoetryTheme.font(20, relativeTo: .title3))
                    .lineSpacing(6).lineLimit(4).foregroundStyle(CreationPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let image = record.input.imageData {
                    PreparedPhoto(data: image, maxPixelSize: 240, contentMode: .fill)
                        .frame(width: 62, height: 76).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                }
            }
            HStack(alignment: .center, spacing: 10) {
                MoodLabel(text: record.input.mood)
                Spacer(minLength: 0)
                Text(favorite ? (line?.favoritedAt?.formatted(date: .abbreviated, time: .omitted) ?? "已收藏") : (oldVersion ? "旧句 · 在版本中查看" : record.favoriteCount > 0 ? "已收藏 \(record.favoriteCount) 句" : "三种文风 · 查看三句"))
                    .font(.caption2).foregroundStyle(CreationPalette.mutedInk)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(favorite ? PoetryTheme.paper(style) : CreationPalette.paper, in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(CreationPalette.ink.opacity(0.10), lineWidth: 1) }
        .padding(.vertical, 1)
    }
    private var emptyView: some View {
        VStack(spacing: 18) {
            Image(systemName: onlyFavorites ? "bookmark" : "text.quote")
                .font(.system(size: 32, weight: .light)).frame(width: 76, height: 76)
                .background(CreationPalette.ink.opacity(0.06), in: Circle())
            Text(searchText.isEmpty ? (onlyFavorites ? "把喜欢的句子留下来" : "第一句，留给今天吧") : "没有找到相关句子")
                .font(PoetryTheme.font(23, relativeTo: .title2)).multilineTextAlignment(.center)
            Text(searchText.isEmpty ? (onlyFavorites ? "在结果卡片上点一下收藏，\n喜欢的那句就会留在这里。" : "写出三句后，会自动保存在这里。") : "试试画面、心情或句子里的字。")
                .font(.subheadline).foregroundStyle(CreationPalette.mutedInk).multilineTextAlignment(.center)
            if searchText.isEmpty {
                Button(action: startCreation) { Text("去创作").foregroundStyle(CreationPalette.pearl) }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(CreationPalette.ink)
            } else {
                Button("清空搜索") { query = "" }.buttonStyle(.bordered).controlSize(.large).tint(CreationPalette.ink)
            }
        }
        .foregroundStyle(CreationPalette.ink).frame(maxWidth: .infinity).padding(.vertical, 40)
        .listRowBackground(Color.clear).listRowSeparator(.hidden)
    }
}

private struct FavoriteReference: Identifiable {
    let creation: Creation
    let line: SentenceVersion
    var id: UUID { line.id }
}

private struct FavoriteDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let creationID: UUID
    let sentenceID: UUID
    var editInput: (UUID) -> Void
    @State private var copied = false
    private var record: Creation? { store.record(creationID) }
    private var line: SentenceVersion? { record?.versions.first { $0.id == sentenceID } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("有一句，替你说中了。")
                        .font(PoetryTheme.font(28, relativeTo: .title)).padding(.bottom, 4)
                    if let record, let line {
                        if let data = record.input.imageData {
                            PreparedPhoto(data: data, maxPixelSize: 1280, contentMode: .fit)
                                .frame(maxWidth: .infinity).frame(height: 190)
                                .background(CreationPalette.ink.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 22))
                                .accessibilityLabel("这句收藏的配图")
                        }
                        PoetrySurface(color: PoetryTheme.paper(line.style)) {
                            VStack(alignment: .leading, spacing: 22) {
                                HStack { PoetryStyleLabel(style: line.style); Spacer(); Image(systemName: "bookmark.fill").foregroundStyle(PoetryTheme.accent(line.style)).accessibilityHidden(true) }
                                Text(line.text).font(PoetryTheme.font(27, relativeTo: .title2)).lineSpacing(10).textSelection(.enabled)
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 12) { actions(line) }
                                    VStack(alignment: .leading, spacing: 10) { actions(line) }
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text(record.input.summary).font(.subheadline).lineSpacing(4)
                            MoodLabel(text: record.input.mood)
                            if let date = line.favoritedAt {
                                Text("收藏于 " + date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(CreationPalette.mutedInk)
                            }
                        }.padding(.horizontal, 3)
                        NavigationLink {
                            ResultView(creationID: creationID) { dismiss(); editInput(creationID) }
                        } label: {
                            Label("查看本次三句", systemImage: "arrow.up.right")
                                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 50)
                        }.buttonStyle(.bordered).tint(CreationPalette.ink)
                    }
                }.padding(22)
            }
            .foregroundStyle(CreationPalette.ink).background { PoetryPaperBackground() }
            .navigationTitle("收藏的句子").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PoetryTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar).toolbarColorScheme(.light, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.foregroundStyle(CreationPalette.ink) } }
            .tint(CreationPalette.ink)
        }
        .sensoryFeedback(.success, trigger: copied)
    }
    @ViewBuilder private func actions(_ line: SentenceVersion) -> some View {
        Button { UIPasteboard.general.string = line.text; copied = true } label: {
            Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc").foregroundStyle(CreationPalette.pearl)
        }
            .buttonStyle(.borderedProminent).tint(CreationPalette.ink).controlSize(.large)
        ShareLink(item: line.text) { Label("分享", systemImage: "square.and.arrow.up") }
            .buttonStyle(.bordered).tint(CreationPalette.ink).controlSize(.large)
    }
}
