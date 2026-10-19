import SwiftUI
import PhotosUI
import SanjuCore

struct CreationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicType
    let openResult: (UUID) -> Void
    @State private var input = CreationInput()
    @State private var photoItem: PhotosPickerItem?
    @State private var showingPhotos = false
    @State private var showingCamera = false
    @State private var showingConsent = false
    @State private var showingAccess = false
    @State private var generateAfterConsent = false
    @State private var readingPhoto = false
    @State private var photoTask: Task<Void, Never>?
    @State private var photoRequest = UUID()
    @FocusState private var focused: Field?
    private enum Field: Hashable { case scene, mood }
    private let moods = ["开心", "平静", "想念", "孤单", "释然", "期待"]

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    introduction
                    photoSection
                    writingPaper
                    previousCreation
                    Button("隐私与 AI 数据用途") { generateAfterConsent = false; showingConsent = true }
                        .font(.caption).foregroundStyle(CreationPalette.pearl.opacity(0.84))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focused) { _, field in
                guard let field else { return }
                Task { @MainActor in
                    // Reveal the active field after the keyboard reserves its space.
                    try? await Task.sleep(for: .milliseconds(150))
                    guard focused == field else { return }
                    scroll.scrollTo(field, anchor: .center)
                }
            }
        }
        .background { CreationOceanBackground() }
        .navigationTitle("三句").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(CreationPalette.coral)
        .safeAreaInset(edge: .bottom, spacing: 0) { creationBar }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focused == .scene { Button("填写心情") { focused = .mood } }
                Spacer()
                Button("完成") { focused = nil }.accessibilityIdentifier("dismissCreationKeyboard")
            }
        }
        .photosPicker(isPresented: $showingPhotos, selection: $photoItem, matching: .images)
        .sheet(isPresented: $showingCamera) {
            CameraPicker { data in showingCamera = false; if let data { preparePhoto(data) } }.ignoresSafeArea()
        }
        .sheet(isPresented: $showingAccess) { BetaAccessView() }
        .sheet(isPresented: $showingConsent) {
            ConsentView { if await store.acceptConsent() { showingConsent = false; if generateAfterConsent && input.validationMessage == nil { generate() } } }
        }
        .onChange(of: photoItem) { _, item in if let item { loadPhoto(item) } }
        .onAppear { input = store.draft }
        .onChange(of: store.draft) { _, value in if value != input { input = value } }
        .onChange(of: input) { _, value in store.updateDraft(value) }
        .onDisappear { Task { await store.flushDraft() } }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("把此刻，写成诗。")
                .font(.custom("SanjuPoetry-Regular", size: 33, relativeTo: .largeTitle))
                .tracking(1).foregroundStyle(CreationPalette.pearl).accessibilityAddTraits(.isHeader)
            Text("一帧光影，一点心绪，三种回响。")
                .font(.subheadline).tracking(0.5).foregroundStyle(CreationPalette.pearl.opacity(0.86))
            if store.isDemo {
                Label("示例体验 · 固定文案，不调用 AI", systemImage: "sparkle")
                    .font(.caption2).foregroundStyle(CreationPalette.pearl.opacity(0.84))
            }
        }.padding(.bottom, 2)
    }

    private var photoSection: some View {
        VStack(spacing: 0) {
            if let data = input.imageData {
                ZStack {
                    CreationPalette.ocean.opacity(0.6)
                    PreparedPhoto(data: data, maxPixelSize: 1280, contentMode: .fit)
                        .frame(maxWidth: .infinity).frame(height: 190).accessibilityLabel("所选照片")
                }
                .frame(height: 190).clipped()
                .overlay(alignment: .topTrailing) {
                    Button { removePhoto() } label: {
                        Image(systemName: "xmark").font(.subheadline.weight(.semibold))
                            .frame(width: 44, height: 44).background(CreationPalette.ocean.opacity(0.88), in: Circle())
                    }
                    .foregroundStyle(CreationPalette.pearl).accessibilityLabel("移除照片").padding(8)
                }
            } else {
                Button { choosePhoto() } label: {
                    HStack(spacing: 15) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 25, weight: .light))
                            .foregroundStyle(CreationPalette.coral).frame(width: 52, height: 58)
                            .background(CreationPalette.pearl.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("拾一帧光影").font(.custom("SanjuPoetry-Regular", size: 22, relativeTo: .title3)).tracking(2)
                            Text("从相册选一张，让画面替你开场").font(.caption).foregroundStyle(CreationPalette.pearl.opacity(0.88))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(CreationPalette.pearl.opacity(0.7))
                    }
                    .foregroundStyle(CreationPalette.pearl).frame(maxWidth: .infinity).padding(18).contentShape(Rectangle())
                }.buttonStyle(CreationPressStyle()).accessibilityLabel("添加一张照片")
            }
            Rectangle().fill(CreationPalette.pearl.opacity(0.15)).frame(height: 1)
            HStack(spacing: 8) {
                if input.imageData != nil {
                    Button { choosePhoto() } label: { Label("更换照片", systemImage: "photo.on.rectangle").frame(minHeight: 44) }
                } else {
                    Button { focused = .scene } label: { Label("只写画面也可以", systemImage: "pencil.line").frame(minHeight: 44) }
                        .accessibilityIdentifier("writeWithoutPhoto")
                }
                Spacer(minLength: 0)
                Button { takePhoto() } label: { Label("拍一张", systemImage: "camera").frame(minHeight: 44) }.accessibilityIdentifier("takePhoto")
            }
            .font(.caption).buttonStyle(.plain).foregroundStyle(CreationPalette.pearl)
            .frame(minHeight: 46).padding(.horizontal, 16)
        }
        .background(CreationPalette.ocean.opacity(0.30), in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(CreationPalette.pearl.opacity(0.28), lineWidth: 1) }
        .overlay {
            if readingPhoto {
                VStack(spacing: 12) {
                    ProgressView().tint(CreationPalette.pearl)
                    Text("正在拾起这一帧…").font(.subheadline)
                    Button("取消读取") { cancelPhoto() }.font(.caption).frame(minHeight: 44)
                }
                .foregroundStyle(CreationPalette.pearl).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CreationPalette.ocean.opacity(0.95), in: RoundedRectangle(cornerRadius: 24))
            }
        }
    }

    private var writingPaper: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(input.imageData == nil ? "你看到了什么？" : "再添一笔画面").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    if !input.scene.isEmpty { clearButton("清空画面描述") { input.scene = ""; focused = .scene } }
                    else {
                        Text(input.imageData == nil ? "照片 / 文字，任选其一" : "选填")
                            .font(.caption2).foregroundStyle(CreationPalette.mutedInk)
                    }
                }.frame(minHeight: 44)
                TextField("", text: $input.scene,
                          prompt: Text("比如：黄昏的海边，风很轻…").foregroundStyle(CreationPalette.mutedInk), axis: .vertical)
                    .font(.body).lineSpacing(6).lineLimit(2...4)
                    .focused($focused, equals: .scene).submitLabel(.next)
                    .accessibilityLabel("画面描述").accessibilityIdentifier("sceneInput").onSubmit { focused = .mood }
                if focused == .scene || input.scene.count > 180 {
                    Text("\(input.scene.count) / 200").font(.caption2.monospacedDigit())
                        .foregroundStyle(input.scene.count > 200 ? .red : CreationPalette.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }.id(Field.scene)
            Rectangle().fill(CreationPalette.ink.opacity(0.12)).frame(height: 1)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("给此刻一种心情").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "sparkle").font(.caption).foregroundStyle(CreationPalette.mutedInk).accessibilityHidden(true)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: moodColumnCount), spacing: 8) {
                    ForEach(moods, id: \.self) { mood in
                        Button { input.mood = mood; focused = nil } label: {
                            HStack(spacing: 5) {
                                if input.mood == mood { Image(systemName: "checkmark").font(.caption2.weight(.semibold)) }
                                Text(mood).font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(input.mood == mood ? CreationPalette.ink : CreationPalette.ink.opacity(0.055), in: Capsule())
                            .foregroundStyle(input.mood == mood ? CreationPalette.pearl : CreationPalette.ink)
                        }
                        .buttonStyle(CreationPressStyle()).accessibilityLabel(mood)
                        .accessibilityAddTraits(input.mood == mood ? .isSelected : [])
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: "pencil.tip").font(.subheadline).foregroundStyle(CreationPalette.mutedInk).accessibilityHidden(true)
                    TextField("", text: $input.mood, prompt: Text("或写下自己的心情…").foregroundStyle(CreationPalette.mutedInk))
                        .font(.subheadline).focused($focused, equals: .mood).submitLabel(.done)
                        .accessibilityLabel("自定义心情").accessibilityIdentifier("moodInput").onSubmit { focused = nil }
                    if !input.mood.isEmpty { clearButton("清空心情") { input.mood = ""; focused = .mood } }
                }
                .frame(minHeight: 44).padding(.horizontal, 12)
                .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(CreationPalette.ink.opacity(focused == .mood ? 0.5 : 0.12), lineWidth: 1) }
                .id(Field.mood)
                if focused == .mood || input.mood.count > 25 {
                    Text("\(input.mood.count) / 30").font(.caption2.monospacedDigit())
                        .foregroundStyle(input.mood.count > 30 ? .red : CreationPalette.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .foregroundStyle(CreationPalette.ink).tint(CreationPalette.ink)
        .padding(20).background(CreationPalette.paper, in: RoundedRectangle(cornerRadius: 26))
        .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.5), lineWidth: 1) }
    }

    @ViewBuilder private var previousCreation: some View {
        if let pending = store.pending {
            Button { openResult(pending.creationId) } label: { Label(store.isBusy ? "正在写三句，查看进度" : "确认上次创作的结果", systemImage: "clock") }
                .font(.subheadline).foregroundStyle(CreationPalette.pearl).frame(maxWidth: .infinity, minHeight: 44)
        } else if let latest = store.records.first {
            Button { openResult(latest.id) } label: { Label("继续查看上次的三句", systemImage: "arrow.uturn.backward") }
                .font(.subheadline).foregroundStyle(CreationPalette.pearl).frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var creationBar: some View {
        VStack(spacing: 9) {
            Button(action: submit) {
                HStack(spacing: 10) {
                    if store.isBusy { ProgressView().tint(CreationPalette.ink) }
                    else { Image(systemName: "sparkles").font(.subheadline) }
                    Text(store.requiresInvitation && !store.hasAccess ? "输入邀请码，开始内测" : "写出三句").font(.headline).tracking(2)
                    if !store.isBusy { Image(systemName: "arrow.right").font(.subheadline) }
                }
                .foregroundStyle(CreationPalette.ink).frame(maxWidth: .infinity, minHeight: 54)
                .background(generateDisabled ? Color(red: 0.72, green: 0.66, blue: 0.58) : CreationPalette.coral, in: RoundedRectangle(cornerRadius: 19))
                .contentShape(RoundedRectangle(cornerRadius: 19))
            }.buttonStyle(CreationPressStyle()).disabled(generateDisabled)
            Text(readingPhoto ? "照片准备好，就可以开始了" : input.validationMessage ?? quotaText)
                .font(.caption2).foregroundStyle(CreationPalette.pearl.opacity(0.88))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 12)
        .background {
            LinearGradient(stops: [.init(color: CreationPalette.ocean.opacity(0), location: 0), .init(color: CreationPalette.ocean, location: 0.20)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var generateDisabled: Bool {
        (store.hasAccess && input.validationMessage != nil) || readingPhoto || store.pending != nil || store.loadFailed || store.quota?.remaining == 0
    }
    private var moodColumnCount: Int {
        if dynamicType >= .accessibility3 { return 1 }
        return dynamicType.isAccessibilitySize ? 2 : 3
    }
    private var quotaText: String {
        if let quota = store.quota {
            return quota.remaining > 0 ? "今天还可\(store.isDemo ? "体验" : "创作") \(quota.remaining) 次 · 每次含 3 次换句" : "今天的次数已用完，明天 00:00 恢复"
        }
        return "冷峻 · 浪漫 · 青春，每种心绪一句"
    }
    private func clearButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill").font(.system(size: 15))
                .foregroundStyle(CreationPalette.mutedInk).frame(width: 44, height: 44)
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
    private func choosePhoto() { focused = nil; photoItem = nil; showingPhotos = true }
    private func takePhoto() {
        focused = nil
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
        focused = nil; store.updateDraft(input)
        if store.requiresInvitation && !store.hasAccess { showingAccess = true; return }
        if store.isDemo || store.hasConsent { generate() } else { generateAfterConsent = true; showingConsent = true }
    }
    private func generate() { Task { _ = await store.startCreation() } }
}
