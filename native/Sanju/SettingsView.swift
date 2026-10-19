import SwiftUI
import SanjuCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showingConsent = false
    @State private var showingAccess = false
    @State private var showingFeedback = false
    @State private var confirmingClear = false
    var body: some View {
        NavigationStack {
            Form {
                if store.isDemo { Section { DemoBadge(); Text("这里生成的是固定示例文案，帮助你体验流程。示例句库与正式创作分别保存。").font(.footnote).foregroundStyle(.secondary) } }
                if store.requiresInvitation {
                    Section("邀请内测") {
                        LabeledContent("内测状态", value: store.hasAccess ? "已加入" : "尚未加入")
                        Button(store.hasAccess ? "更换邀请码" : "输入邀请码") { showingAccess = true }
                        if store.hasAccess { Button("退出内测") { Task { await store.leave() } } }
                        Button("反馈与帮助") { showingFeedback = true }.disabled(!store.hasAccess)
                    }
                }
                Section("隐私与数据") {
                    Button("查看 AI 数据用途") { showingConsent = true }
                    if store.hasConsent { Button("撤回 AI 处理同意") { Task { await store.revokeConsent() } } }
                    Text("创作与收藏保存在这台设备，首版没有应用内云同步。系统备份是否迁移内容取决于设备设置。").font(.footnote).foregroundStyle(.secondary)
                }
                Section("本地内容") {
                    LabeledContent("创作记录", value: "\(store.records.count) 份")
                    Button("清空本地内容", role: .destructive) { confirmingClear = true }
                }
                Section { Text("三句 · 邀请内测版").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
                .confirmationDialog("清空全部本地内容？", isPresented: $confirmingClear, titleVisibility: .visible) {
                    Button("清空全部内容", role: .destructive) { Task { await store.clear() } }
                } message: { Text("将删除配图、全部句子、收藏与草稿，无法恢复。已使用的创作额度不会恢复。") }
                .sheet(isPresented: $showingAccess) { BetaAccessView() }
                .sheet(isPresented: $showingFeedback) { FeedbackView() }
                .sheet(isPresented: $showingConsent) { ConsentView { if await store.acceptConsent() { showingConsent = false } } }
        }
    }
}

struct ConsentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var accept: () async -> Void
    @State private var accepting = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "hand.raised").font(.system(size: 36, weight: .light)).foregroundStyle(SanjuTheme.accent)
                    Text("生成前，先了解数据用途").font(.title2.weight(.semibold))
                    Text("选择照片和准备输入时，内容只在本机处理。点击生成并同意后，所选照片、画面描述和心情会发送到三句服务端，再交给 OpenRouter 及下游 Qwen 模型，用来生成配文。")
                    Text("三句服务端不保存原始照片、画面描述和心情正文。为恢复网络中断后的结果，生成文本和请求状态最多保留 8 天；换句机会自创作起保留 24 小时。主动提交的反馈最多保留 31 天。请勿提交敏感个人信息。")
                    Link("查看三句内测隐私政策", destination: URL(string: (Bundle.main.object(forInfoDictionaryKey: "SanjuAPIBaseURL") as? String ?? "https://sanju-two.vercel.app") + "/privacy")!)
                    Link("查看 OpenRouter 数据隐私说明", destination: URL(string: "https://openrouter.ai/docs/features/privacy-and-logging")!)
                    if store.isDemo { Text("当前是示例体验，不会发送照片、文字或调用模型。").font(.footnote).foregroundStyle(.secondary) }
                    PrimaryButton(title: store.isDemo ? "继续示例体验" : "同意并继续", busy: accepting, disabled: accepting) {
                        accepting = true
                        Task { await accept(); accepting = false }
                    }
                    Button("暂不使用") { dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
                }.padding(24)
            }.navigationTitle("AI 数据用途").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
        }
    }
}
