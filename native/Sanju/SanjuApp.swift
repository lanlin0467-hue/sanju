import SwiftUI
import SanjuCore

@main struct SanjuApp: App {
    private let persistence: FileLibraryPersistence
    private let service: any GenerationService
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        #if SANJU_PREVIEW
        // Keep the installed preview usable when opened from the Home Screen.
        let demo = true
        #elseif DEBUG
        let demo = arguments.contains("--demo")
        #else
        let demo = false
        #endif
        let defaults = UserDefaults.standard
        let identity = defaults.string(forKey: "installationID") ?? UUID().uuidString
        defaults.set(identity, forKey: "installationID")
        let baseString: String
        let configuredBase = Bundle.main.object(forInfoDictionaryKey: "SanjuAPIBaseURL") as? String ?? "https://sanju-two.vercel.app"
        #if DEBUG || SANJU_PREVIEW
        if let index = arguments.firstIndex(of: "--api-base-url"), arguments.indices.contains(index + 1) { baseString = arguments[index + 1] }
        else { baseString = configuredBase }
        #else
        baseString = configuredBase
        #endif
        let base = URL(string: baseString) ?? URL(string: "https://sanju-two.vercel.app")!
        #if DEBUG
        let requiresInvitation = arguments.contains("--require-invitation") || !(base.host == "127.0.0.1" || base.host == "localhost")
        let credentialAccount: String
        if let index = arguments.firstIndex(of: "--test-library"), arguments.indices.contains(index + 1), let namespace = UUID(uuidString: arguments[index+1]) { credentialAccount = "test-" + namespace.uuidString }
        else { credentialAccount = "session" }
        #else
        let requiresInvitation = true
        let credentialAccount = "session"
        #endif
        service = demo ? DemoGenerationService() : LiveGenerationService(baseURL: base, installationID: identity, credentials: SessionVault(account: credentialAccount), requiresInvitation: requiresInvitation)
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Sanju", isDirectory: true)
        let storage: URL
        #if DEBUG
        if let index = arguments.firstIndex(of: "--test-library"), arguments.indices.contains(index + 1), let namespace = UUID(uuidString: arguments[index + 1]) {
            storage = directory.appendingPathComponent("UITests", isDirectory: true).appendingPathComponent(namespace.uuidString + ".json")
        } else { storage = directory.appendingPathComponent(demo ? "demo-library-v1.json" : "library-v1.json") }
        #else
        storage = directory.appendingPathComponent(demo ? "demo-library-v1.json" : "library-v1.json")
        #endif
        persistence = FileLibraryPersistence(url: storage)
    }
    var body: some Scene { WindowGroup { AppBootstrapView(persistence: persistence, service: service) } }
}

struct AppBootstrapView: View {
    let persistence: any LibraryPersistence
    let service: any GenerationService
    @State private var store: AppStore?
    var body: some View {
        Group {
            if let store { AppRootView().environment(store) }
            else { ProgressView("正在读取句库…").frame(maxWidth: .infinity, maxHeight: .infinity).background(SanjuTheme.background) }
        }
        .tint(SanjuTheme.accent)
        .task { if store == nil { store = await AppStore(persistence: persistence, service: service) } }
    }
}

struct AppRootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var creationPath: [UUID] = []
    @State private var showingSettings = false
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $creationPath) {
                CreationView(openResult: openResult)
                    .navigationDestination(for: UUID.self) { id in
                        ResultView(creationID: id, editInput: { edit(id) })
                    }
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { settingsButton } }
            }
            .tabItem { Label("创作", systemImage: "square.and.pencil") }.tag(0)
            NavigationStack {
                LibraryView(startCreation: { selectedTab = 0; creationPath = [] }, editInput: edit)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { settingsButton } }
            }
            .tabItem { Label("句库", systemImage: "bookmark") }.tag(1)
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .alert("提示", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            if store.loadFailed { Button("重新读取") { Task { await store.reload() } } }
            Button("知道了", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .overlay(alignment: .top) {
            if let notice = store.notice {
                Text(notice).font(.subheadline).padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule()).padding(.top, 8).allowsHitTesting(false)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .task(id: store.notice) {
            guard store.notice != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { store.notice = nil }
        }
        .task {
            await store.refresh()
            if let pending = store.pending { openResult(pending.creationId); await store.recover() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh(); if store.pending != nil { await store.recover() } } }
            if phase == .background {
                let token = UIApplication.shared.beginBackgroundTask(withName: "保存草稿")
                Task {
                    await store.flushDraft()
                    if token != .invalid { UIApplication.shared.endBackgroundTask(token) }
                }
            }
        }
        .onChange(of: store.pending?.creationId) { _, id in
            if let id, store.pending?.style == nil { openResult(id) }
        }
    }
    private var settingsButton: some View {
        Button("设置", systemImage: "slider.horizontal.3") { showingSettings = true }
            .labelStyle(.iconOnly).accessibilityLabel("设置")
    }
    private func openResult(_ id: UUID) { selectedTab = 0; if creationPath.last != id { creationPath.append(id) } }
    private func edit(_ id: UUID) { store.edit(id); selectedTab = 0; creationPath = [] }
}
