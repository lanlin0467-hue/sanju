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
                if store.isDemo { Section { DemoBadge(); Text("这里生成的是固定示例文案，帮助你体验流程。示例句库与正式创作分别保存。").font(.footnote).foregroundStyle(SanjuTheme.secondaryText) } }
                if store.requiresInvitation {
                    Section("邀请内测") {
                        LabeledContent("内测状态", value: store.hasAccess ? "已加入" : "尚未加入")
                        Button(store.hasAccess ? "更换邀请码" : "输入邀请码") { showingAccess = true }
                        if store.hasAccess { Button("退出内测") { Task { await store.leave() } } }
                        Button("反馈与帮助") { showingFeedback = true }.disabled(!store.hasAccess)
                    }
                }
                Section("隐私与数据") {
                    NavigationLink("完整隐私说明") { PrivacyPolicyView() }
                    Button("查看 AI 数据用途") { showingConsent = true }
                    if store.hasConsent { Button("撤回 AI 处理同意") { Task { await store.revokeConsent() } } }
                    Text("创作与收藏保存在这台设备，首版没有应用内云同步。系统备份是否迁移内容取决于设备设置。").font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
                }
                Section("本地内容") {
                    LabeledContent("创作记录", value: "\(store.records.count) 份")
                    Button("清空本地内容", role: .destructive) { confirmingClear = true }
                }
                Section { Text("三句 · 邀请内测版").font(.footnote).foregroundStyle(SanjuTheme.secondaryText) }
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
    var generating = false
    var accept: () async -> Void
    @State private var accepting = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "lock").font(.system(size: 28)).foregroundStyle(SanjuTheme.accent)
                        .frame(width: 64, height: 64).background(SanjuTheme.tintSoft, in: Circle())
                    Text("生成前，先说清楚").font(.title2.bold())
                    Text("三句需要把这一次的素材交给 AI，才能写出句子。")
                        .font(.subheadline).foregroundStyle(SanjuTheme.secondaryText).multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 24) {
                        explanation("会发送什么", symbol: "photo", text: "你选的照片、画面描述和心情，只发送这次的内容；选择素材时仅在本机处理。")
                        explanation("用来做什么", symbol: "sparkle", text: "经三句服务端交给 OpenRouter 和 Qwen 模型生成配文。使用禁止训练数据收集的路由；服务商保留规则以其政策为准。")
                        explanation("存在哪里", symbol: "iphone", text: "句库保存在这台设备，没有应用内云同步，卸载会删除。三句服务端不保存原始素材；为找回结果，文本和请求状态最多保留 8 天，主动反馈最多保留 31 天。")
                    }
                    VStack(spacing: 8) {
                        NavigationLink { PrivacyPolicyView() } label: {
                            Text("阅读完整隐私说明").frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                        }
                        Link("OpenRouter 数据隐私说明", destination: URL(string: "https://openrouter.ai/docs/features/privacy-and-logging")!).font(.footnote).frame(minHeight: 44)
                    }
                    if store.isDemo { DemoBadge() }
                    Text("请勿提交敏感个人信息。之后可在设置中查看或撤回同意。")
                        .font(.footnote).foregroundStyle(SanjuTheme.secondaryText).multilineTextAlignment(.center)
                }.padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    PrimaryButton(title: store.isDemo ? "继续示例体验" : generating ? "同意并生成" : "同意并继续", busy: accepting, disabled: accepting) {
                        accepting = true
                        Task { await accept(); accepting = false }
                    }
                    Button("暂不") { dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
                }.padding(.horizontal, 24).padding(.top, 8).background(SanjuTheme.surface)
            }
            .background(SanjuTheme.surface).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
        }.presentationDetents([.height(640), .large]).presentationDragIndicator(.visible)
    }
    private func explanation(_ title: String, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(SanjuTheme.accent).frame(width: 26)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(SanjuTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// Kept in-app so the complete notice remains readable before the production
// /privacy page is deployed, and while the device is offline.
struct PrivacyPolicyView: View {
    var body: some View {
        Form {
            Section {
                Text("三句 · 邀请内测隐私说明").font(.title2.bold())
                Text("生效日期：2026 年 10 月 19 日").font(.footnote).foregroundStyle(SanjuTheme.secondaryText)
            }
            Section("你提供的内容如何使用") {
                Text("选图和准备输入时，照片、画面描述和心情在设备上处理。点击生成并明确同意后，所选照片的压缩副本、画面描述和心情才会通过 HTTPS 发送到三句服务端，再交给 OpenRouter 及其下游 Qwen 模型服务商，用于本次生成；换句也使用原来的素材。")
                Text("三句服务端不把原始照片、画面描述和心情正文写入数据库，也不在应用日志中记录这些内容。第三方模型服务处理内容的规则以其隐私政策为准，请勿提交敏感个人信息。")
                Link("OpenRouter 隐私政策", destination: URL(string: "https://openrouter.ai/privacy")!)
            }
            Section("保存哪些数据") {
                Text("照片的压缩副本、草稿、全部句子版本和收藏保存在你的设备。应用没有句库云同步；系统备份可能按你的系统设置处理这些数据。卸载应用会删除本机内容。")
                Text("服务端保存邀请码摘要、匿名内测标识和会话凭据摘要，用于准入、次数计算和防止重复扣次。生成文本、请求状态和素材摘要最多保留 8 天；换句机会保留 24 小时。反馈只在你主动提交时发送，最多保留 31 天。")
                Text("连接服务时使用临时的网络地址摘要限制异常请求，最多保留 2 天；托管服务商可能保留正常运行所需的网络日志。本内测版没有广告、跨应用跟踪或出售个人数据的功能。")
            }
            Section("你的选择") {
                Text("你可以只用文字创作；可以在设置中撤回 AI 处理同意、退出内测，以及清空本机句库。清空本地内容不会自动删除服务端用于恢复的记录，它们按上述期限清理。系统相机权限可在 iPhone 设置中调整。")
                Text("如需提前删除服务端记录或了解处理情况，可通过设置中的「反馈与帮助」联系内测维护者，也可以联系邀请你参加测试的联系人。核对内测身份后会处理；资格到期后可通过原邀请联系人提出请求。")
            }
            Section("内测范围与变更") {
                Text("本版本仅供受邀测试者使用。数据用途或服务商发生实质变更时，会更新说明，并在需要时重新征得同意。示例体验不发送素材，也不调用模型。")
            }
        }.navigationTitle("隐私说明").navigationBarTitleDisplayMode(.inline)
    }
}
