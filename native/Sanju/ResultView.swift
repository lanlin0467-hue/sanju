import SwiftUI
import SanjuCore

struct ResultView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let creationID: UUID
    var editInput: () -> Void
    @State private var historyStyle: WritingStyle?
    @State private var copied: UUID?
    @State private var showingFeedback = false
    @State private var showingAccess = false
    private var record: Creation? { store.record(creationID) }
    private var pending: PendingGeneration? { store.pending?.creationId == creationID ? store.pending : nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                introduction
                if let record {
                    context(record.input)
                    savedStatus(record)
                    ForEach(WritingStyle.allCases) { style in
                        if let line = record.current(style) { sentenceCard(record, line: line) }
                    }
                    if let pending, !store.isBusy { recovery(pending) }
                    footer(record)
                } else if let pending {
                    context(pending.input)
                    Label(store.isBusy ? "正在把这一刻，慢慢写成三句…" : "这次结果还需要确认", systemImage: "sparkles")
                        .font(.subheadline).foregroundStyle(CreationPalette.pearl)
                    ForEach(WritingStyle.allCases) { style in
                        PoetrySurface(color: PoetryTheme.paper(style)) {
                            VStack(alignment: .leading, spacing: 18) {
                                PoetryStyleLabel(style: style)
                                RoundedRectangle(cornerRadius: 5).fill(CreationPalette.ink.opacity(0.08)).frame(height: 18)
                                RoundedRectangle(cornerRadius: 5).fill(CreationPalette.ink.opacity(0.08)).frame(maxWidth: 180).frame(height: 18)
                            }.padding(.vertical, 6)
                        }
                    }
                    if store.isBusy {
                        ProgressView().tint(CreationPalette.pearl).frame(maxWidth: .infinity)
                        Text("可以先去句库，回来后继续查看。").font(.caption).foregroundStyle(CreationPalette.pearl)
                    } else { recovery(pending) }
                } else {
                    PoetrySurface {
                        ContentUnavailableView("这次还没写好", systemImage: "cloud", description: Text("原来的输入已保留，返回创作页后可以重试。"))
                            .foregroundStyle(CreationPalette.ink)
                    }
                }
            }.padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 28)
        }
        .background { CreationOceanBackground() }
        .navigationTitle("本次三句").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CreationPalette.ocean, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
        .tint(CreationPalette.coral)
        .sheet(isPresented: $showingAccess) { BetaAccessView() }
        .sheet(isPresented: $showingFeedback) { FeedbackView(creationID: creationID) }
        .sheet(item: $historyStyle) { style in SentenceHistoryView(creationID: creationID, style: style) }
        .sensoryFeedback(.success, trigger: copied)
        .task(id: copied) {
            guard copied != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { copied = nil }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("此刻，有了回响。")
                .font(PoetryTheme.font(31, relativeTo: .largeTitle)).foregroundStyle(CreationPalette.pearl)
                .accessibilityAddTraits(.isHeader)
            Text("三种心绪，留一句最像你的。")
                .font(.subheadline).foregroundStyle(CreationPalette.pearl.opacity(0.85))
        }.padding(.bottom, 3)
    }

    private func context(_ input: CreationInput) -> some View {
        HStack(alignment: .center, spacing: 14) {
            if let image = input.imageData {
                PreparedPhoto(data: image, maxPixelSize: 360, contentMode: .fit)
                    .frame(width: 62, height: 74).background(CreationPalette.ocean.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel("本次创作的照片")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(input.summary).font(.subheadline).lineSpacing(3).lineLimit(3).accessibilityLabel(input.summary)
                Label(input.mood, systemImage: "heart").font(.caption).foregroundStyle(CreationPalette.pearl.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(CreationPalette.pearl).padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CreationPalette.ocean.opacity(0.45), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(CreationPalette.pearl.opacity(0.18), lineWidth: 1) }
    }

    private func savedStatus(_ record: Creation) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) { savedLabel(record); Spacer(minLength: 0); swapCount(record) }
            VStack(alignment: .leading, spacing: 6) { savedLabel(record); swapCount(record) }
        }
        .font(.caption).foregroundStyle(CreationPalette.pearl.opacity(0.9))
        .padding(.horizontal, 2).padding(.vertical, 3)
    }
    private func savedLabel(_ record: Creation) -> some View {
        Label(store.isSaved(creationID) ? (record.isDemo ? "示例内容 · 已存入句库" : "已存入句库") : "尚未保存，可以先复制", systemImage: store.isSaved(creationID) ? "checkmark.circle" : "exclamationmark.triangle")
    }
    private func swapCount(_ record: Creation) -> some View {
        Text(record.expiresAt > Date() ? "还可换 \(record.swapsRemaining) 句" : "换句机会已到期")
    }

    private func sentenceCard(_ record: Creation, line: SentenceVersion) -> some View {
        let swapping = pending?.style == line.style && store.isBusy
        return PoetrySurface(color: PoetryTheme.paper(line.style)) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 10) {
                            Text(PoetryTheme.number(line.style)).font(.caption.monospacedDigit()).foregroundStyle(CreationPalette.mutedInk)
                            PoetryStyleLabel(style: line.style)
                        }
                        Text(line.style.subtitle).font(.caption).foregroundStyle(CreationPalette.mutedInk)
                    }
                    Spacer(minLength: 0)
                    Button { Task { await store.toggleFavorite(creationID: creationID, sentenceID: line.id) } } label: {
                        Image(systemName: line.favoritedAt == nil ? "bookmark" : "bookmark.fill")
                            .font(.system(size: 18)).frame(width: 44, height: 44)
                            .background(PoetryTheme.accent(line.style).opacity(line.favoritedAt == nil ? 0.04 : 0.12), in: Circle())
                    }
                    .buttonStyle(CreationPressStyle()).foregroundStyle(PoetryTheme.accent(line.style))
                    .disabled(!store.isSaved(creationID))
                    .accessibilityLabel(line.favoritedAt == nil ? "收藏\(line.style.title)这句" : "取消收藏\(line.style.title)这句")
                }
                Text(line.text).font(PoetryTheme.font(23, relativeTo: .title3)).lineSpacing(9)
                    .foregroundStyle(CreationPalette.ink).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity).animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: line.id)
                    .padding(.vertical, 2)
                Rectangle().fill(PoetryTheme.accent(line.style).opacity(0.13)).frame(height: 1)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { copyButton(line); swapButton(record, line: line, swapping: swapping); Spacer(minLength: 0); moreMenu(line) }
                    VStack(alignment: .leading, spacing: 8) { copyButton(line); swapButton(record, line: line, swapping: swapping); moreMenu(line) }
                }
                .font(.subheadline)
            }
        }.sensoryFeedback(.selection, trigger: line.favoritedAt)
    }
    private func copyButton(_ line: SentenceVersion) -> some View {
        Button { UIPasteboard.general.string = line.text; copied = line.id; store.notice = "已复制" } label: {
            Label(copied == line.id ? "已复制" : "复制", systemImage: copied == line.id ? "checkmark" : "doc.on.doc")
                .fixedSize(horizontal: true, vertical: false).padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(CreationPalette.pearl).background(CreationPalette.ink, in: Capsule())
        }.buttonStyle(CreationPressStyle())
    }
    private func swapButton(_ record: Creation, line: SentenceVersion, swapping: Bool) -> some View {
        Button { Task { await store.replace(creationID, style: line.style) } } label: {
            HStack(spacing: 6) {
                if swapping { ProgressView().tint(CreationPalette.ink) }
                else { Image(systemName: "arrow.triangle.2.circlepath").font(.caption) }
                Text(swapping ? "正在换…" : "换这句")
            }
            .fixedSize(horizontal: true, vertical: false).padding(.horizontal, 12).frame(minHeight: 44)
            .foregroundStyle(CreationPalette.ink.opacity(store.canSwap(record) || swapping ? 1 : 0.42))
            .background(CreationPalette.ink.opacity(0.055), in: Capsule())
        }.buttonStyle(CreationPressStyle()).disabled(!store.canSwap(record))
    }
    private func moreMenu(_ line: SentenceVersion) -> some View {
        Menu {
            ShareLink(item: line.text) { Label("分享文字", systemImage: "square.and.arrow.up") }
            Button("查看本次旧句", systemImage: "clock.arrow.circlepath") { historyStyle = line.style }
            if !store.isDemo { Button("反馈这份创作", systemImage: "exclamationmark.bubble") { showingFeedback = true } }
        } label: {
            Image(systemName: "ellipsis").font(.headline).foregroundStyle(CreationPalette.ink).frame(width: 44, height: 44)
        }.accessibilityLabel("\(line.style.title)更多操作")
    }
    private func footer(_ record: Creation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if record.swapsRemaining == 0 {
                Text("本次换句已用完，仍可复制、收藏或分享。").font(.footnote)
            }
            Button { editInput() } label: {
                Label("用这个画面再写", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 50)
                    .background(CreationPalette.pearl.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                    .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(CreationPalette.pearl.opacity(0.3), lineWidth: 1) }
            }.buttonStyle(CreationPressStyle())
            Text("调整后再次生成，会使用一次新的创作额度。").font(.caption)
        }.foregroundStyle(CreationPalette.pearl.opacity(0.9)).padding(.top, 4)
    }
    private func recovery(_ pending: PendingGeneration) -> some View {
        PoetrySurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("先找回这次结果，避免重复使用额度。").font(.footnote).foregroundStyle(CreationPalette.mutedInk)
                if store.requiresInvitation && !store.hasAccess {
                    PrimaryButton(title: "输入邀请码，确认结果") { showingAccess = true }
                } else { PrimaryButton(title: "确认这次结果") { Task { await store.recover() } } }
            }.tint(CreationPalette.ink)
        }
    }
}

private struct SentenceHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let creationID: UUID
    let style: WritingStyle
    private var record: Creation? { store.record(creationID) }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("每一句，都有来处。")
                        .font(PoetryTheme.font(27, relativeTo: .title)).padding(.bottom, 2)
                    Text("恢复旧句不会使用换句次数，收藏也会保留。")
                        .font(.caption).foregroundStyle(CreationPalette.mutedInk)
                    if let record {
                        ForEach(record.versions.filter { $0.style == style }.reversed()) { line in
                            let current = record.current(style)?.id == line.id
                            PoetrySurface(color: PoetryTheme.paper(style)) {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text(line.createdAt.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(CreationPalette.mutedInk)
                                        Spacer()
                                        if line.favoritedAt != nil { Label("已收藏", systemImage: "bookmark.fill").font(.caption).foregroundStyle(PoetryTheme.accent(style)) }
                                    }
                                    Text(line.text).font(PoetryTheme.font(21, relativeTo: .title3)).lineSpacing(7).textSelection(.enabled)
                                    Button {
                                        Task { await store.selectVersion(creationID: creationID, sentenceID: line.id); dismiss() }
                                    } label: {
                                        Text(current ? "当前句子" : "用这一句")
                                            .foregroundStyle(current ? CreationPalette.mutedInk : CreationPalette.pearl)
                                    }
                                    .font(.subheadline.weight(.medium)).frame(minHeight: 44).buttonStyle(.borderedProminent)
                                    .tint(CreationPalette.ink).disabled(current)
                                }
                            }
                        }
                    }
                }.padding(22)
            }
            .foregroundStyle(CreationPalette.ink).background { PoetryPaperBackground() }
            .navigationTitle("\(style.title)的本次版本").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(PoetryTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar).toolbarColorScheme(.light, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() }.foregroundStyle(CreationPalette.ink).accessibilityIdentifier("dismissSentenceHistory") } }
            .tint(CreationPalette.ink)
        }
    }
}
