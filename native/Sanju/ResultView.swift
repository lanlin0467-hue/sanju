import SwiftUI
import SanjuCore

struct ResultView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let creationID: UUID
    var editInput: () -> Void
    var showLibrary: (() -> Void)? = nil
    @State private var showingHistory = false
    @State private var copied: UUID?
    @State private var showingFeedback = false
    @State private var showingAccess = false
    private var record: Creation? { store.record(creationID) }
    private var pending: PendingGeneration? { store.pending?.creationId == creationID ? store.pending : nil }
    private var failed: PendingGeneration? { store.failedOperation?.creationId == creationID ? store.failedOperation : nil }
    private var oldCount: Int { guard let record else { return 0 }; return max(0, record.versions.count - WritingStyle.allCases.count) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let record {
                    ContextSummary(input: record.input, date: record.createdAt)
                    VStack(spacing: 12) {
                        SectionHeading(title: "三种文风", detail: record.expiresAt > Date() ? "可换 \(record.swapsRemaining) 次 · 24 小时内有效" : "换句已过期")
                        ForEach(Array(WritingStyle.allCases.enumerated()), id: \.element) { index, style in
                            if let line = record.current(style) {
                                SentenceResultCard(record: record, line: line, pending: pending, failed: failed?.style == style, copied: copied == line.id) { copy(line) }
                                    .modifier(SentenceArrival(delay: Double(index) * 0.08))
                            }
                        }
                    }
                    if !store.isSaved(creationID) {
                        Label("尚未保存，可以先复制。请腾出设备空间，再找回并保存结果。", systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
                    } else {
                        Label(record.isDemo ? "示例内容 · 已存入句库" : "已存入句库", systemImage: "checkmark.circle")
                            .font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
                    }
                    if let pending, !store.isBusy { recovery(pending) }
                    Button("用这个画面再写", systemImage: "square.and.pencil", action: editInput).frame(maxWidth: .infinity, minHeight: 44)
                    Text("再次生成会使用一次新的创作额度。").font(.caption).foregroundStyle(SanjuTheme.secondaryText).frame(maxWidth: .infinity)
                } else if let pending {
                    ContextSummary(input: pending.input, date: pending.startedAt)
                    if store.isBusy { generating } else { recovery(pending) }
                } else {
                    if let failed { ContextSummary(input: failed.input, date: failed.startedAt) }
                    Surface {
                        VStack(spacing: 12) {
                            ContentUnavailableView("这次没有写好", systemImage: "cloud", description: Text(store.failureDescription ?? "原来的照片、画面和心情都还在，可以返回后重试。"))
                            if let failed, store.draft != failed.input {
                                Text("你在等待时更新的草稿已保留，可以返回后继续创作。")
                                    .font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
                            } else {
                                PrimaryButton(title: "重试") { Task { _ = await store.startCreation() } }
                            }
                            Button("返回修改", action: editInput).frame(minHeight: 44)
                            Text("未成功的创作不消耗创作次数，素材已保留。").font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
                        }
                    }
                }
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 24)
        }
        .background(SanjuTheme.background)
        .navigationTitle("三句").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if record != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingHistory = true } label: {
                        HStack(spacing: 4) { Image(systemName: "clock.arrow.circlepath"); if oldCount > 0 { Text("\(oldCount)").font(.caption.weight(.semibold)) } }.frame(minWidth: 44, minHeight: 44)
                    }.accessibilityLabel("旧句（\(oldCount) 条）").accessibilityIdentifier("sentenceHistory")
                }
                if !store.isDemo {
                    ToolbarItem(placement: .secondaryAction) { Button("反馈这份创作") { showingFeedback = true } }
                }
            }
        }
        .sheet(isPresented: $showingAccess) { BetaAccessView() }
        .sheet(isPresented: $showingFeedback) { FeedbackView(creationID: creationID) }
        .sheet(isPresented: $showingHistory) { SentenceHistoryView(creationID: creationID) }
        .sensoryFeedback(.success, trigger: copied)
        .task(id: copied) {
            guard copied != nil else { return }; try? await Task.sleep(for: .milliseconds(1600))
            if !Task.isCancelled { copied = nil }
        }
    }
    private func copy(_ line: SentenceVersion) { UIPasteboard.general.string = line.text; copied = line.id; store.notice = "已复制" }
    private var generating: some View {
        VStack(spacing: 20) {
            ProgressView("正在生成三句…").frame(maxWidth: .infinity).padding(.vertical, 16)
            ForEach(WritingStyle.allCases) { style in
                Surface { VStack(alignment: .leading, spacing: 20) { Text(style.title).font(.footnote.weight(.semibold)).foregroundStyle(SanjuTheme.secondaryText); SentencePlaceholder() } }
            }
            Text("可以先离开此页面。生成完成后会自动保存到句库；网络中断时回来即可找回，不会重复扣除次数。")
                .font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
        }
    }
    private func recovery(_ pending: PendingGeneration) -> some View {
        Surface {
            VStack(spacing: 12) {
                ContentUnavailableView(store.hasAccess ? "网络中断，结果待确认" : "重新加入内测，找回结果", systemImage: "wifi.slash", description: Text("请求已经发出，三句可能已经写好。找回结果只查询这次请求，不会重新生成，也不会重复扣次数。"))
                PrimaryButton(title: store.hasAccess ? "找回结果" : "输入邀请码", busy: store.isBusy, disabled: store.isBusy) {
                    if !store.hasAccess { showingAccess = true } else { Task { await store.recover() } }
                }
                if let showLibrary { Button("稍后在句库查看", action: showLibrary).frame(minHeight: 44) }
            }
        }
    }
}

private struct SentenceResultCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicType
    let record: Creation
    let line: SentenceVersion
    let pending: PendingGeneration?
    let failed: Bool
    let copied: Bool
    var copy: () -> Void
    private var swapping: Bool { pending?.style == line.style && store.isBusy }
    private var unavailable: String? {
        if record.expiresAt <= Date() { return "换句已过期" }
        if record.swapsRemaining == 0 { return "换句次数已用完" }
        return nil
    }
    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 8) {
                Text(line.style.title).font(.footnote.weight(.semibold)).foregroundStyle(SanjuTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .overlay(alignment: .trailing) {
                    FavoriteButton(line: line, disabled: !store.isSaved(record.id)) { Task { await store.toggleFavorite(creationID: record.id, sentenceID: line.id) } }
                    }
                Group {
                    if swapping { SentencePlaceholder() }
                    else { SentenceText(text: line.text).id(line.id).transition(.opacity) }
                }.frame(minHeight: 64, alignment: .topLeading)
                if failed { Text("没换成，原句已保留。" + (store.failureDescription ?? "请稍后重试。" )).font(.footnote).foregroundStyle(SanjuTheme.secondaryText) }
                if dynamicType.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) { copyButton; shareButton; swapButton }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { copyButton; shareButton; Spacer(minLength: 0); swapButton }
                        VStack(alignment: .leading, spacing: 0) { HStack(spacing: 16) { copyButton; shareButton }; swapButton }
                    }
                }
            }
        }
    }
    private var copyButton: some View {
        Button(action: copy) { Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc").frame(minHeight: 44) }.buttonStyle(.plain).foregroundStyle(SanjuTheme.accent)
    }
    private var shareButton: some View {
        ShareLink(item: line.text) { Label("分享", systemImage: "square.and.arrow.up").frame(minHeight: 44) }.buttonStyle(.plain).foregroundStyle(SanjuTheme.accent)
    }
    private var swapButton: some View {
        Button { Task { await store.replace(record.id, style: line.style) } } label: {
            HStack(spacing: 5) {
                if swapping { ProgressView() }
                else if unavailable == nil { Image(systemName: "arrow.triangle.2.circlepath") }
                Text(swapping ? "正在换…" : unavailable ?? (failed ? "重试" : "换一句"))
            }.font(unavailable == nil ? .body : .footnote).frame(minHeight: 44)
        }.buttonStyle(.plain).foregroundStyle(unavailable == nil ? SanjuTheme.accent : SanjuTheme.secondaryText)
            .disabled(!store.canSwap(record)).accessibilityIdentifier("swap_" + line.style.rawValue)
    }
}

struct SentencePlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .systemGray5)).frame(height: 18)
            RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .systemGray5)).frame(maxWidth: 190).frame(height: 18)
        }.frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).accessibilityLabel("正在写这句")
    }
}

private struct SentenceArrival: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    func body(content: Content) -> some View {
        content.opacity(appeared ? 1 : 0).offset(y: appeared || reduceMotion ? 0 : 8)
            .task { withAnimation(.easeOut(duration: 0.25).delay(delay)) { appeared = true } }
    }
}

struct SentenceHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let creationID: UUID
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("恢复旧句不消耗换句次数", systemImage: "checkmark.circle")
                        .font(.subheadline).foregroundStyle(SanjuTheme.accent).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(SanjuTheme.tintSoft, in: RoundedRectangle(cornerRadius: 16))
                    if let record = store.record(creationID) {
                        ForEach(WritingStyle.allCases) { style in
                            VStack(spacing: 8) {
                                SectionHeading(title: style.title)
                                Surface {
                                    VStack(alignment: .leading, spacing: 16) {
                                        if let current = record.current(style) {
                                            historyText(current)
                                            HStack { MoodLabel(text: "当前"); favoriteLabel(current) }
                                        }
                                        let old = record.versions.filter { $0.style == style && $0.id != record.current(style)?.id }.sorted { ($0.replacedAt ?? $0.createdAt) > ($1.replacedAt ?? $1.createdAt) }
                                        if old.isEmpty { Text("还没有换过").font(.subheadline).foregroundStyle(SanjuTheme.secondaryText) }
                                        ForEach(old) { line in
                                            Divider()
                                            VStack(alignment: .leading, spacing: 8) {
                                                historyText(line)
                                                ViewThatFits(in: .horizontal) {
                                                    HStack { versionMetadata(line); Spacer(minLength: 8); restoreButton(line) }
                                                    VStack(alignment: .leading) { versionMetadata(line); restoreButton(line) }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text("旧句跟随这次创作一起保存在句库。收藏过的句子即使被换下，也会一直留在「收藏」里。")
                        .font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
                }.padding(20)
            }.background(SanjuTheme.background).navigationTitle("旧句").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.accessibilityIdentifier("dismissSentenceHistory") } }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
    }
    private func historyText(_ line: SentenceVersion) -> some View { SentenceText(text: line.text, size: 18, relativeTo: .body) }
    private func favoriteLabel(_ line: SentenceVersion) -> some View {
        Group {
            if line.favoritedAt != nil {
                HStack(spacing: 4) { Image(systemName: "star.fill").foregroundStyle(SanjuTheme.favorite); Text("已收藏").foregroundStyle(SanjuTheme.secondaryText) }
            }
        }.font(.footnote)
    }
    private func versionMetadata(_ line: SentenceVersion) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text((line.replacedAt == nil ? "生成于 " : "换下于 ") + (line.replacedAt ?? line.createdAt).formatted(date: .omitted, time: .shortened))
                .font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
            favoriteLabel(line)
        }
    }
    private func restoreButton(_ line: SentenceVersion) -> some View {
        Button("恢复") { Task { await store.selectVersion(creationID: creationID, sentenceID: line.id) } }
            .buttonStyle(.bordered).buttonBorderShape(.capsule).frame(minHeight: 44).disabled(!store.isSaved(creationID))
            .accessibilityIdentifier("restore_" + line.style.rawValue)
    }
}
