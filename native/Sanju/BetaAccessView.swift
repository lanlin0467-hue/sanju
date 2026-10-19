import SwiftUI
import SanjuCore

struct BetaAccessView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var busy = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "ticket").font(.system(size: 36, weight: .light)).foregroundStyle(SanjuTheme.accent)
                    Text("欢迎来试试三句").font(.title2.weight(.semibold))
                    Text("输入收到的邀请码，即可体验真实 AI 创作。内测期间免费，每天可创作 5 次，每份三句共享 3 次换句机会。").foregroundStyle(.secondary)
                    SecureField("粘贴内测邀请码", text: $code).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(16).background(SanjuTheme.surface, in: RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier("betaInviteInput")
                    PrimaryButton(title: "加入内测", busy: busy, disabled: code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy) {
                        busy = true
                        Task { if await store.join(code) { dismiss() }; busy = false }
                    }
                    Text("同一个邀请码的使用额度会合并计算，请保留自己的邀请码。句库仍保存在这台设备。").font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }.background(SanjuTheme.background).navigationTitle("加入内测").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("稍后") { dismiss() } } }
        }
    }
}

struct FeedbackView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var creationID: UUID?
    @State private var category = "quality"
    @State private var note = ""
    @State private var busy = false
    var body: some View {
        NavigationStack {
            Form {
                Picker("反馈类型", selection: $category) { Text("句子不合适").tag("quality"); Text("内容不当").tag("inappropriate"); Text("功能问题").tag("problem") }
                Section("想告诉我们什么？") {
                    TextEditor(text: $note).frame(minHeight: 160).accessibilityIdentifier("feedbackInput")
                    Text("\(note.count) / 500").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Text("提交后会发送反馈文字\(creationID == nil ? "" : "和这份创作的标识")，不会附带照片。请勿填写敏感个人信息。").font(.footnote).foregroundStyle(.secondary)
                    PrimaryButton(title: "提交反馈", busy: busy, disabled: busy || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || note.count > 500) {
                        busy = true
                        Task { if await store.feedback(category: category, note: note, creationID: creationID) { dismiss() }; busy = false }
                    }
                }
            }.navigationTitle("反馈与帮助").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("取消") { dismiss() } } }
        }
    }
}
