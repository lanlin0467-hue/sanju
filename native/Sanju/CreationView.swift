import SwiftUI
import PhotosUI
import SanjuCore

struct CreationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let openResult: (UUID) -> Void
    @State private var photoItem: PhotosPickerItem?
    @State private var showingPhotos = false
    @State private var showingCamera = false
    @State private var showingConsent = false
    @State private var showingAccess = false
    @State private var showingQuota = false
    @State private var showingSettings = false
    @State private var openSettingsAfterQuota = false
    @State private var showingCustomMood = false
    @State private var customMood = ""
    @State private var savedCustomMood = ""
    @State private var recoveredDraft: CreationInput?
    @State private var didLoad = false
    @State private var readingPhoto = false
    @State private var photoTask: Task<Void, Never>?
    @State private var photoRequest = UUID()
    @State private var limitFeedback = 0
    @FocusState private var sceneFocused: Bool
    private let moods = ["开心", "平静", "想念", "孤单", "释然", "期待"]
    private var input: CreationInput {
        get { store.draft }
        nonmutating set { store.updateDraft(newValue) }
    }
    private var sceneBinding: Binding<String> {
        Binding(get: { input.scene }, set: { value in
            var next = input
            next.scene = value
            input = next
        })
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if store.isDemo { DemoBadge() }
                        if recoveredDraft != nil { draftBanner }
                        VStack(spacing: 8) {
                            SectionHeading(title: "画面", detail: "照片或文字，至少一项")
                            sceneCard(photoHeight: geometry.size.height < 540 ? 120 : 160)
                        }
                        VStack(spacing: 8) {
                            SectionHeading(title: "心情", detail: "必选")
                            moodCard
                        }
                        if let pending = store.pending {
                            Button { openResult(pending.creationId) } label: {
                                Label(store.isBusy ? "正在生成，查看进度" : "结果待确认 · 点按找回", systemImage: "clock.arrow.circlepath")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                    }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: sceneFocused) { _, focused in
                    if focused {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(150))
                            if sceneFocused { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { scroll.scrollTo("sceneEditor", anchor: .center) } }
                        }
                    }
                }
            }
        }
        .background(SanjuTheme.background)
        .navigationTitle("创作").navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingQuota = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                        Text(store.quota.map { "剩余 \($0.remaining) 次" } ?? "内测额度")
                    }.font(.subheadline.weight(.medium)).fixedSize(horizontal: true, vertical: false).frame(minHeight: 44)
                }.accessibilityLabel(store.quota.map { "今日剩余 \($0.remaining) 次，共 5 次" } ?? "查看内测额度")
            }
            if sceneFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("完成") { sceneFocused = false }.accessibilityIdentifier("dismissCreationKeyboard")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { creationBar }
        .photosPicker(isPresented: $showingPhotos, selection: $photoItem, matching: .images)
        .sheet(isPresented: $showingCamera) { CameraPicker { data in showingCamera = false; if let data { preparePhoto(data) } }.ignoresSafeArea() }
        .sheet(isPresented: $showingAccess) { BetaAccessView() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingQuota, onDismiss: {
            if openSettingsAfterQuota { openSettingsAfterQuota = false; showingSettings = true }
        }) { quotaSheet }
        .sheet(isPresented: $showingConsent) {
            ConsentView(generating: true) {
                if await store.acceptConsent() { showingConsent = false; if input.validationMessage == nil { generate() } }
            }
        }
        .background {
            CustomMoodPrompt(isPresented: $showingCustomMood, initialText: customMood) { value in
                savedCustomMood = value; input.mood = value
            }.frame(width: 0, height: 0)
        }
        .onChange(of: photoItem) { _, item in if let item { loadPhoto(item) } }
        .onAppear {
            guard !didLoad else { return }
            if !moods.contains(input.mood) { savedCustomMood = input.mood }
            if !input.isEmpty { recoveredDraft = input }; didLoad = true
        }
        .onChange(of: store.draft) { _, value in
            if value.scene.count > 200 {
                var next = value; next.scene = String(value.scene.prefix(200)); input = next
                limitFeedback += 1
            }
            if value.isEmpty { savedCustomMood = "" }
            else if !value.mood.isEmpty && !moods.contains(value.mood) { savedCustomMood = value.mood }
            if let recoveredDraft, recoveredDraft != value { self.recoveredDraft = nil }
        }
        .onDisappear { Task { await store.flushDraft() } }
        .sensoryFeedback(.selection, trigger: input.mood)
        .sensoryFeedback(.impact(weight: .light), trigger: limitFeedback)
    }

    private var draftBanner: some View {
        Surface {
            HStack(spacing: 10) {
                Button {
                    if let recoveredDraft { input = recoveredDraft }; recoveredDraft = nil; store.notice = "草稿已恢复"
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.uturn.backward").foregroundStyle(SanjuTheme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("继续上次的草稿").font(.body).foregroundStyle(.primary)
                            Text((store.state.draftUpdatedAt.map { $0.formatted(.dateTime.month().day().hour().minute()) + " · " } ?? "") + String((recoveredDraft?.summary ?? "").prefix(20)))
                                .font(.footnote).foregroundStyle(SanjuTheme.secondaryText).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Button { cancelPhoto(); input = CreationInput(); recoveredDraft = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(SanjuTheme.secondaryText).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("忽略草稿")
            }
        }
    }

    private func sceneCard(photoHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            if let data = input.imageData {
                PreparedPhoto(data: data, maxPixelSize: 1280, contentMode: .fill)
                    .frame(maxWidth: .infinity).frame(height: photoHeight).clipped()
                    .accessibilityLabel("所选照片")
                    .overlay(alignment: .topTrailing) {
                        Button { removePhoto() } label: {
                            Image(systemName: "xmark").font(.subheadline.weight(.semibold)).frame(width: 44, height: 44)
                                .background(.black.opacity(0.45), in: Circle())
                        }.foregroundStyle(.white).accessibilityLabel("移除照片").padding(8)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Button("更换") { choosePhoto() }.font(.subheadline.weight(.semibold)).padding(.horizontal, 16).frame(minHeight: 44)
                            .background(.ultraThinMaterial, in: Capsule()).accessibilityLabel("更换照片").padding(10)
                    }
            } else {
                photoRow("从相册选择", symbol: "photo", action: choosePhoto).accessibilityIdentifier("choosePhoto")
                Divider().padding(.leading, 52)
                photoRow("拍照", symbol: "camera", action: takePhoto).accessibilityIdentifier("takePhoto")
            }
            Divider().padding(.horizontal, 16)
            VStack(alignment: .trailing, spacing: 8) {
                TextField("描述画面（选填）", text: sceneBinding, axis: .vertical)
                    .font(.body).lineSpacing(4).lineLimit(2...6).focused($sceneFocused)
                    .accessibilityLabel("画面描述").accessibilityIdentifier("sceneInput")
                HStack {
                    if !input.scene.isEmpty {
                        Button("清空画面描述", systemImage: "xmark.circle") { input.scene = "" }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                    }
                    Spacer(); Text("\(input.scene.count)/200").font(.caption).foregroundStyle(SanjuTheme.secondaryText)
                }
            }.padding(16).id("sceneEditor")
        }
        .background(SanjuTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            if readingPhoto {
                VStack(spacing: 12) {
                    ProgressView("正在读取照片…")
                    Button("取消读取") { cancelPhoto() }.frame(minHeight: 44)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).background(SanjuTheme.surface, in: RoundedRectangle(cornerRadius: 22))
            }
        }
    }
    private func photoRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding(.horizontal, 16).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(SanjuTheme.accent)
    }
    private var moodCard: some View {
        Surface {
            MoodFlowLayout {
                ForEach(moods, id: \.self) { mood in moodChip(mood) }
                if !savedCustomMood.isEmpty && !moods.contains(savedCustomMood) {
                    moodChip(savedCustomMood).contextMenu {
                        Button("修改心情") { customMood = savedCustomMood; showingCustomMood = true }
                        Button("移除自定义心情") { if input.mood == savedCustomMood { input.mood = "" }; savedCustomMood = "" }
                    }
                } else {
                    Button { sceneFocused = false; customMood = ""; showingCustomMood = true } label: {
                        Label("自定义", systemImage: "plus").padding(.horizontal, 14).frame(minHeight: 44).background(SanjuTheme.fill, in: Capsule())
                    }.buttonStyle(.plain).foregroundStyle(SanjuTheme.accent).accessibilityIdentifier("customMood")
                }
            }
        }
    }
    private func moodChip(_ mood: String) -> some View {
        let selected = input.mood == mood
        return Button { input.mood = selected ? "" : mood; sceneFocused = false } label: {
            HStack(spacing: 6) { if selected { Image(systemName: "checkmark").font(.footnote.weight(.semibold)) }; Text(mood).fontWeight(selected ? .semibold : .regular) }
                .padding(.horizontal, 15).frame(minHeight: 44)
                .foregroundStyle(selected ? (colorScheme == .dark ? Color.black : .white) : .primary)
                .background(selected ? SanjuTheme.accent : SanjuTheme.fill, in: Capsule())
        }.buttonStyle(.plain).accessibilityLabel(mood).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var creationBar: some View {
        VStack(spacing: 8) {
            PrimaryButton(title: buttonTitle, busy: store.isBusy, disabled: generateDisabled, action: submit).accessibilityIdentifier("generateSentences")
            if store.quota?.remaining == 0 { Text("每日 00:00（北京时间）恢复 5 次创作机会").font(.caption).foregroundStyle(SanjuTheme.secondaryText) }
        }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12).background(SanjuTheme.background)
    }
    private var buttonTitle: String {
        if store.requiresInvitation && !store.hasAccess { return "输入邀请码，开始内测" }
        if store.isBusy { return "正在生成…" }
        if store.pending != nil { return "请先找回上次结果" }
        if store.quota?.remaining == 0 { return "今日次数已用完" }
        if readingPhoto { return "正在读取照片…" }
        if input.imageData == nil && input.scene.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "添加照片或描述画面" }
        if input.mood.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "选择心情后生成" }
        return "生成三句"
    }
    private var generateDisabled: Bool {
        (store.hasAccess && input.validationMessage != nil) || readingPhoto || store.isBusy || store.pending != nil || store.loadFailed || store.quota?.remaining == 0
    }
    private var quotaSheet: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("今日剩余", value: store.quota.map { "\($0.remaining) 次" } ?? "加入内测后查看")
                    Text("免费内测每天可创作 5 次，每日 00:00（北京时间）恢复。每份创作含 3 次共享换句，24 小时内有效。恢复旧句不消耗次数。")
                        .font(.subheadline).foregroundStyle(SanjuTheme.secondaryText)
                }
                if store.isDemo { Section { DemoBadge() } }
                Section { Button("隐私与设置") { openSettingsAfterQuota = true; showingQuota = false } }
            }.navigationTitle("创作额度").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showingQuota = false } } }
        }.presentationDetents([.medium, .large])
    }
    private func choosePhoto() { sceneFocused = false; photoItem = nil; showingPhotos = true }
    private func takePhoto() {
        sceneFocused = false
        if UIImagePickerController.isSourceTypeAvailable(.camera) { showingCamera = true }
        else { store.errorMessage = "这台设备暂时无法拍照，请从相册选择。" }
    }
    private func cancelPhoto() {
        photoTask?.cancel(); photoTask = nil
        photoRequest = UUID(); readingPhoto = false
    }
    private func removePhoto() { cancelPhoto(); input.imageData = nil; photoItem = nil }
    private func loadPhoto(_ item: PhotosPickerItem) {
        cancelPhoto()
        let request = photoRequest
        readingPhoto = true
        photoTask = Task { @MainActor in
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoProcessor.PhotoError.unreadable }
                try Task.checkCancellation()
                try await finishPhoto(data, request: request)
            } catch {
                guard !Task.isCancelled, photoRequest == request else { return }
                readingPhoto = false
                store.errorMessage = "照片暂时无法读取，请检查网络或重新选择，也可以先写下画面。"
            }
        }
    }
    private func preparePhoto(_ data: Data) {
        cancelPhoto()
        let request = photoRequest
        readingPhoto = true
        photoTask = Task { @MainActor in
            do { try await finishPhoto(data, request: request) }
            catch {
                guard !Task.isCancelled, photoRequest == request else { return }
                readingPhoto = false; store.errorMessage = error.localizedDescription
            }
        }
    }
    @MainActor private func finishPhoto(_ data: Data, request: UUID) async throws {
        let processed = try await Task.detached(priority: .userInitiated) { try PhotoProcessor.prepare(data) }.value
        guard !Task.isCancelled, photoRequest == request else { return }
        input.imageData = processed
        readingPhoto = false; photoTask = nil
    }
    private func submit() {
        sceneFocused = false; store.updateDraft(input)
        if store.requiresInvitation && !store.hasAccess { showingAccess = true; return }
        if store.isDemo || store.hasConsent { generate() } else { showingConsent = true }
    }
    private func generate() { Task { _ = await store.startCreation() } }
}
