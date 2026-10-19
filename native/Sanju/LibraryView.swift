import SwiftUI
import SanjuCore

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var onlyFavorites = false
    @State private var query = ""
    @State private var deleting: Creation?
    var startCreation: () -> Void
    var editInput: (UUID) -> Void
    private var searchText: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasContent: Bool { !store.records.isEmpty || store.pending != nil }
    private var entries: [LibraryEntry] {
        var entries = store.records.flatMap { record -> [LibraryEntry] in
            if onlyFavorites {
                return record.versions.filter { line in
                    line.favoritedAt != nil && (searchText.isEmpty || line.text.localizedStandardContains(searchText) || record.input.scene.localizedStandardContains(searchText) || record.input.mood.localizedStandardContains(searchText))
                }.map { .init(id: $0.id, date: $0.favoritedAt ?? record.createdAt, record: record, line: $0) }
            }
            guard record.matches(searchText) else { return [] }
            let line: SentenceVersion?
            if !searchText.isEmpty, let match = record.versions.reversed().first(where: { $0.text.localizedStandardContains(searchText) }) { line = match }
            else { line = record.versions.last(where: { $0.favoritedAt != nil }) ?? record.current(.cool) }
            return [.init(id: record.id, date: record.createdAt, record: record, line: line)]
        }
        if !onlyFavorites, let pending = store.pending, pending.style == nil, !store.records.contains(where: { $0.id == pending.creationId }),
           searchText.isEmpty || pending.input.scene.localizedStandardContains(searchText) || pending.input.mood.localizedStandardContains(searchText) {
            entries.append(.init(id: pending.creationId, date: pending.startedAt, pending: pending))
        }
        return entries.sorted { $0.date > $1.date }
    }
    private var days: [Date] { Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).sorted(by: >) }

    var body: some View {
        Group {
            if hasContent {
                libraryList.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索句子、画面或心情")
            } else {
                ContentUnavailableView {
                    Label("还没有句子", systemImage: "text.quote")
                } description: { Text("写下一个画面和此刻的心情，\n三句会替你把这一刻留下。") }
                actions: { Button("开始创作", action: startCreation).buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large) }
            }
        }
        .background(SanjuTheme.background)
        .navigationTitle("句库").navigationBarTitleDisplayMode(.large)
        .alert("删除这次创作？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除", role: .destructive) { if let deleting { Task { await store.delete(deleting.id) } }; deleting = nil }
        } message: { Text(deleting?.deletionMessage ?? "") }
    }
    private var libraryList: some View {
        List {
            Section {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { filter; localOnly }
                    VStack(alignment: .leading, spacing: 8) { filter; localOnly }
                }.listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)).listRowBackground(Color.clear)
            }
            if entries.isEmpty {
                Section {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                        Button("清空搜索") { query = "" }.frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        ContentUnavailableView("还没有收藏", systemImage: "star", description: Text("在句子卡片上轻点星标，\n喜欢的那句就会留在这里。"))
                    }
                }.listRowBackground(Color.clear)
            }
            ForEach(days, id: \.self) { day in
                Section {
                    ForEach(entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }) { item in
                        if let record = item.record, let line = item.line {
                            NavigationLink {
                                FavoriteDetailView(creationID: record.id, sentenceID: line.id, editInput: editInput)
                            } label: { sentenceRow(item, record: record, line: line) }
                                .accessibilityIdentifier((onlyFavorites ? "libraryFavorite_" : "libraryRecord_") + item.id.uuidString)
                                .swipeActions {
                                    Button("删除", systemImage: "trash", role: .destructive) { deleting = record }
                                    if onlyFavorites { Button("取消收藏", systemImage: "star.slash") { Task { await store.toggleFavorite(creationID: record.id, sentenceID: line.id) } }.tint(SanjuTheme.accent) }
                                }
                                .contextMenu { Button("删除创作", systemImage: "trash", role: .destructive) { deleting = record } }
                        } else if let pending = item.pending {
                            NavigationLink {
                                ResultView(creationID: pending.creationId, editInput: { editInput(pending.creationId) })
                            } label: {
                                HStack(spacing: 12) {
                                    InputThumbnail(input: pending.input)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(store.isBusy ? "正在生成三句…" : "结果待确认").foregroundStyle(SanjuTheme.secondaryText)
                                        Text(store.isBusy ? "完成后自动保存" : "点按找回 · " + pending.startedAt.formatted(date: .omitted, time: .shortened))
                                            .font(.footnote).foregroundStyle(SanjuTheme.accent)
                                    }
                                }.padding(.vertical, 4)
                            }.accessibilityIdentifier("pendingLibraryRecord")
                        }
                    }.listRowBackground(SanjuTheme.surface)
                } header: { Text(dayTitle(day)).textCase(nil).foregroundStyle(SanjuTheme.secondaryText) }
            }
        }.listStyle(.insetGrouped).listSectionSpacing(24).scrollContentBackground(.hidden).scrollDismissesKeyboard(.interactively)
    }
    private var filter: some View {
        Picker("句库范围", selection: $onlyFavorites) { Text("全部").tag(false); Text("收藏").tag(true) }.pickerStyle(.segmented)
    }
    private var localOnly: some View {
        Label("仅保存在本机", systemImage: "iphone").labelStyle(.titleAndIcon).font(.caption).foregroundStyle(SanjuTheme.secondaryText).fixedSize()
    }
    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.month().day())
    }
    private func sentenceRow(_ item: LibraryEntry, record: Creation, line: SentenceVersion) -> some View {
        LibrarySentenceRow(record: record, line: line, date: item.date, showFavorite: onlyFavorites || record.favoriteCount > 0, isOldMatch: !searchText.isEmpty && record.current(line.style)?.id != line.id)
    }
}

private struct LibraryEntry: Identifiable {
    let id: UUID
    let date: Date
    var record: Creation? = nil
    var line: SentenceVersion? = nil
    var pending: PendingGeneration? = nil
}

private struct LibrarySentenceRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicType
    let record: Creation
    let line: SentenceVersion
    let date: Date
    let showFavorite: Bool
    let isOldMatch: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !dynamicType.isAccessibilitySize { InputThumbnail(input: record.input) }
            VStack(alignment: .leading, spacing: 6) {
                Text(line.text).font(PoetryTheme.font(16, relativeTo: .body)).lineSpacing(4).lineLimit(2).foregroundStyle(.primary)
                Text(record.input.mood + " · " + date.formatted(date: .omitted, time: .shortened))
                    .font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
                if isOldMatch { Text("旧句 · 在版本中查看").font(.caption).foregroundStyle(SanjuTheme.secondaryText) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if showFavorite { Image(systemName: "star.fill").font(.footnote).foregroundStyle(SanjuTheme.favorite).accessibilityLabel("已收藏") }
        }.padding(.vertical, 4)
    }
}

struct FavoriteDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicType
    let creationID: UUID
    let sentenceID: UUID
    var editInput: (UUID) -> Void
    @State private var selection: UUID?
    @State private var copied = false
    @State private var confirmingDelete = false
    @State private var showingHistory = false
    private var record: Creation? { store.record(creationID) }
    private var line: SentenceVersion? { record?.versions.first { $0.id == (selection ?? sentenceID) } }
    var body: some View {
        ScrollView {
            if let record, let line {
                VStack(alignment: .leading, spacing: 24) {
                    if let data = record.input.imageData {
                        PreparedPhoto(data: data, maxPixelSize: 1280, contentMode: .fill)
                            .frame(maxWidth: .infinity).frame(height: 168).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)).accessibilityLabel("这句的配图")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(line.style.title).font(.footnote.weight(.semibold)).foregroundStyle(SanjuTheme.secondaryText)
                            Spacer()
                            FavoriteButton(line: line) { Task { await store.toggleFavorite(creationID: creationID, sentenceID: line.id) } }
                        }
                        SentenceText(text: line.text, size: 25, relativeTo: .title)
                        Text(record.input.mood + " · " + record.createdAt.formatted(.dateTime.month().day().hour().minute()) + " · " + record.input.summary)
                            .font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
                        if record.current(line.style)?.id != line.id {
                            Text("这是一句旧版本，收藏仍为你保留。").font(.caption).foregroundStyle(SanjuTheme.secondaryText)
                        }
                    }.padding(.horizontal, 4)
                    if dynamicType.isAccessibilitySize {
                        VStack(spacing: 12) { copyButton(line); shareButton(line) }
                    } else {
                        HStack(spacing: 12) { copyButton(line); shareButton(line) }
                    }
                    VStack(spacing: 8) {
                        SectionHeading(title: "本次三句")
                        VStack(spacing: 0) {
                            ForEach(WritingStyle.allCases) { style in
                                if let current = record.current(style) {
                                    Button { selection = current.id; copied = false } label: {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(style.title + (current.id == line.id ? " · 正在查看" : ""))
                                                    .font(.footnote.weight(.semibold)).foregroundStyle(current.id == line.id ? SanjuTheme.accent : SanjuTheme.secondaryText)
                                                Text(current.text).font(PoetryTheme.font(16, relativeTo: .body)).lineSpacing(4).multilineTextAlignment(.leading).foregroundStyle(.primary)
                                            }.frame(maxWidth: .infinity, alignment: .leading)
                                            Image(systemName: current.id == line.id ? "checkmark" : "chevron.right").foregroundStyle(current.id == line.id ? SanjuTheme.accent : SanjuTheme.secondaryText)
                                        }.padding(16).frame(minHeight: 44).contentShape(Rectangle())
                                    }.buttonStyle(.plain).accessibilityIdentifier("detail_" + style.rawValue)
                                    if style != .youth { Divider().padding(.horizontal, 16) }
                                }
                            }
                        }.background(SanjuTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    NavigationLink("查看本次三句") { ResultView(creationID: creationID) { editInput(creationID) } }.frame(maxWidth: .infinity, minHeight: 44)
                }.padding(20)
            }
        }.background(SanjuTheme.background)
            .navigationTitle("句子详情").navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("查看旧句", systemImage: "clock.arrow.circlepath") { showingHistory = true }
                        Button("删除创作", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("详情更多操作")
                }
            }
            .alert("删除这次创作？", isPresented: $confirmingDelete) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task { await store.delete(creationID); if store.record(creationID) == nil { dismiss() } }
                }
            } message: { Text(record?.deletionMessage ?? "") }
            .sheet(isPresented: $showingHistory) { SentenceHistoryView(creationID: creationID) }
            .sensoryFeedback(.success, trigger: copied)
            .task(id: copied) { if copied { try? await Task.sleep(for: .milliseconds(1600)); if !Task.isCancelled { copied = false } } }
    }
    private func copyButton(_ line: SentenceVersion) -> some View {
        Button { UIPasteboard.general.string = line.text; copied = true; store.notice = "已复制" } label: { Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc") }.buttonStyle(SoftButtonStyle())
    }
    private func shareButton(_ line: SentenceVersion) -> some View {
        ShareLink(item: line.text) { Label("分享", systemImage: "square.and.arrow.up") }.buttonStyle(SoftButtonStyle())
    }
}
