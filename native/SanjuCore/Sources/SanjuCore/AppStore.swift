import Foundation
import Observation

@MainActor @Observable public final class AppStore {
    @ObservationIgnored public private(set) var state = LibraryState()
    public private(set) var records: [Creation] = []
    public private(set) var draft = CreationInput()
    public private(set) var quota: CreationQuota?
    public private(set) var pending: PendingGeneration?
    public private(set) var hasConsent = false
    public private(set) var hasAccess = false
    public var requiresInvitation: Bool { service.requiresInvitation }
    public private(set) var isBusy = false
    public private(set) var loadFailed = false
    public private(set) var unsavedRecords: [UUID: Creation] = [:]
    public var errorMessage: String?
    public var notice: String?
    public let isDemo: Bool
    public static let consentVersion = "2026-10-19-beta-v2"
    @ObservationIgnored private let storage: LibraryStorage
    @ObservationIgnored private let service: any GenerationService
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var mutationTail: Task<Void, Never>?
    @ObservationIgnored private var draftSaveTask: Task<Void, Never>?

    public init(persistence: any LibraryPersistence, service: any GenerationService, now: @escaping () -> Date = Date.init) async {
        storage = LibraryStorage(persistence); self.service = service; self.now = now; isDemo = service.isDemo
        hasAccess = await service.hasAccess()
        do {
            let loaded = try await storage.load()
            publish(loaded); draft = loaded.draft
        } catch { loadFailed = true; errorMessage = "句库暂时无法读取。已有文件没有覆盖，请重试读取。" }
        if isDemo && (quota == nil || quota!.resetsAt <= now()) {
            var next = state; next.quota = .demo(now: now()); publish(next)
        }
    }
    private func publish(_ next: LibraryState) {
        // A draft save must not invalidate the library or result views.
        if state.records != next.records { records = next.records.sorted { $0.createdAt > $1.createdAt } }
        if quota != next.quota { quota = next.quota }
        if pending != next.pending { pending = next.pending }
        let consent = next.consentVersion == Self.consentVersion
        if hasConsent != consent { hasConsent = consent }
        state = next
    }
    public func record(_ id: UUID) -> Creation? { unsavedRecords[id] ?? records.first { $0.id == id } }
    public func isSaved(_ id: UUID) -> Bool { unsavedRecords[id] == nil && records.contains { $0.id == id } }
    public func canSwap(_ record: Creation) -> Bool { !isBusy && pending == nil && record.swapsRemaining > 0 && record.expiresAt > now() }

    // Keep read/modify/write transactions ordered across awaits. Publishing only
    // after a successful write preserves rollback and request-recovery semantics.
    private func serialized(_ work: @escaping @MainActor () async -> Bool) async -> Bool {
        let previous = mutationTail
        let task = Task { @MainActor in
            await previous?.value
            return await work()
        }
        mutationTail = Task { _ = await task.value }
        return await task.value
    }
    @discardableResult private func mutate(_ change: @escaping @MainActor (inout LibraryState) -> Bool) async -> Bool {
        await serialized {
            guard !self.loadFailed else { self.errorMessage = "请先恢复句库读取，避免覆盖已有内容。"; return false }
            var next = self.state
            guard change(&next) else { return false }
            guard next != self.state else { return true }
            do { try await self.storage.save(next); self.publish(next); return true }
            catch { self.errorMessage = "暂时没能保存，请检查设备空间后重试。"; return false }
        }
    }
    public func updateDraft(_ input: CreationInput) {
        guard input != draft else { return }
        draft = input
        draftSaveTask?.cancel()
        draftSaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard !Task.isCancelled, let self else { return }
            await self.flushDraft()
        }
    }
    @discardableResult public func flushDraft() async -> Bool {
        await mutate { next in next.draft = self.draft; return true }
    }
    public func acceptConsent() async -> Bool { await mutate { $0.consentVersion = Self.consentVersion; return true } }
    public func revokeConsent() async {
        if await mutate({ $0.consentVersion = nil; return true }) { notice = "已撤回，下次生成前会重新询问" }
    }
    public func reload() async {
        _ = await serialized {
            do {
                let loaded = try await self.storage.load()
                self.publish(loaded); self.draft = loaded.draft; self.loadFailed = false; self.errorMessage = nil
                return true
            } catch { self.errorMessage = "还是无法读取句库，已有内容没有覆盖。"; return false }
        }
    }
    public func join(_ code: String) async -> Bool {
        do { try await service.join(code); hasAccess = true; await refresh(); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }
    public func leave() async {
        do { try await service.leave() } catch { errorMessage = error.localizedDescription }
        hasAccess = false
    }
    public func feedback(category: String, note: String, creationID: UUID? = nil) async -> Bool {
        do { try await service.feedback(category: category, note: note, creationID: creationID); notice = "反馈已收到，谢谢你帮三句变得更好"; return true }
        catch { if error as? GenerationError == .unauthorized { hasAccess = false }; errorMessage = error.localizedDescription; return false }
    }
    public func refresh() async {
        guard hasAccess else { return }
        if isDemo {
            await mutate { next in
                if next.quota == nil || next.quota!.resetsAt <= self.now() { next.quota = .demo(now: self.now()) }
                return true
            }
        } else if let quota = try? await service.quota() {
            await mutate { $0.quota = quota; return true }
        }
    }
    public func startCreation() async -> UUID? {
        guard !isBusy, pending == nil, !loadFailed else { return pending?.creationId }
        guard hasAccess else { errorMessage = GenerationError.unauthorized.localizedDescription; return nil }
        let input = draft
        if let message = input.validationMessage { errorMessage = message; return nil }
        guard hasConsent || isDemo else { errorMessage = "请先同意 AI 数据处理说明。"; return nil }
        // Reserve immediately, before either quota refresh or storage can suspend.
        isBusy = true
        defer { isBusy = false }
        await refresh()
        let id = UUID()
        let operation = PendingGeneration(creationId: id, input: input, startedAt: now())
        guard await mutate({ next in
            guard next.pending == nil else { return false }
            guard self.hasConsent || self.isDemo else { self.errorMessage = "请先同意 AI 数据处理说明。"; return false }
            if let quota = next.quota, quota.remaining <= 0 { self.errorMessage = "今天的创作次数已用完，明天 00:00 恢复。"; return false }
            next.draft = self.draft; next.pending = operation; return true
        }) else { return nil }
        await run(operation, recovering: false)
        return id
    }
    public func replace(_ id: UUID, style: WritingStyle) async {
        guard let record = record(id), canSwap(record) else { return }
        guard hasConsent || isDemo else { errorMessage = "请先在设置中查看并同意 AI 数据处理说明。"; return }
        isBusy = true
        defer { isBusy = false }
        let operation = PendingGeneration(creationId: id, input: record.input, style: style, previous: record.versions.filter { $0.style == style }.map(\.text), startedAt: now())
        guard await mutate({ next in
            guard next.pending == nil, next.records.contains(where: { $0.id == id }) else { return false }
            next.pending = operation; return true
        }) else { return }
        await run(operation, recovering: false)
    }
    public func recover() async {
        guard let operation = pending, !isBusy else { return }
        guard hasConsent || isDemo else { errorMessage = "重新确认结果前，请先同意 AI 数据处理说明。"; return }
        isBusy = true
        defer { isBusy = false }
        await run(operation, recovering: true)
    }
    private func run(_ operation: PendingGeneration, recovering: Bool) async {
        errorMessage = nil
        do {
            let reply = try await (recovering ? service.recover(operation) : service.perform(operation))
            try validate(reply, operation: operation)
            var generated: Creation?
            let saved = await mutate { next in
                if let style = operation.style, let index = next.records.firstIndex(where: { $0.id == operation.creationId }) {
                    let line = SentenceVersion(style: style, text: reply.lines[0].text, createdAt: self.now())
                    next.records[index].versions.append(line); next.records[index].selected[style.rawValue] = line.id
                    next.records[index].swapsRemaining = self.isDemo ? max(0, next.records[index].swapsRemaining - 1) : reply.swapsRemaining
                } else if operation.style == nil && !next.records.contains(where: { $0.id == operation.creationId }) {
                    let record = Creation(id: operation.creationId, input: operation.input, createdAt: operation.startedAt, expiresAt: reply.expiresAt, swapsRemaining: reply.swapsRemaining, versions: reply.lines.map { .init(style: $0.style, text: $0.text, createdAt: self.now()) }, isDemo: self.isDemo)
                    next.records.insert(record, at: 0)
                    if self.isDemo { let remaining = max(0, (next.quota?.remaining ?? 5) - 1); next.quota?.remaining = remaining }
                    next.draft = self.draft == operation.input ? CreationInput() : self.draft
                }
                if let quota = reply.quota { next.quota = quota }
                next.pending = nil
                generated = next.records.first { $0.id == operation.creationId }
                return true
            }
            if saved {
                if operation.style == nil && draft == operation.input { updateDraft(CreationInput()) }
                unsavedRecords[operation.creationId] = nil
                notice = operation.style == nil ? "三句写好了，已存入句库" : "已换一句"
            } else { unsavedRecords[operation.creationId] = generated; notice = "内容已写好，暂时未能保存，可以先复制。" }
        } catch {
            let problem = error as? GenerationError
            if problem == .unauthorized { hasAccess = false }
            if problem != .uncertain && problem != .processing && problem != .unauthorized {
                await mutate { $0.pending = nil; return true }
            }
            errorMessage = error.localizedDescription
        }
    }
    private func validate(_ reply: GenerationReply, operation: PendingGeneration) throws {
        let expected = operation.style.map { [$0] } ?? WritingStyle.allCases
        guard reply.creationId == operation.creationId, reply.lines.count == expected.count,
              Set(reply.lines.map(\.style)) == Set(expected), (0...3).contains(reply.swapsRemaining),
              reply.lines.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw GenerationError.message("这次返回的句子不完整，请稍后重试。")
        }
        if let style = operation.style, let text = reply.lines.first?.text,
           operation.previous.contains(text) || reply.lines.first?.style != style {
            throw GenerationError.message("这句和刚才一样，换句次数已保留。")
        }
    }
    public func toggleFavorite(creationID: UUID, sentenceID: UUID) async {
        var favorited = false
        if await mutate({ next in
            guard let i = next.records.firstIndex(where: { $0.id == creationID }), let j = next.records[i].versions.firstIndex(where: { $0.id == sentenceID }) else { return false }
            next.records[i].versions[j].favoritedAt = next.records[i].versions[j].favoritedAt == nil ? self.now() : nil
            favorited = next.records[i].versions[j].favoritedAt != nil
            return true
        }) { notice = favorited ? "已收藏这句" : "已取消收藏" }
    }
    public func selectVersion(creationID: UUID, sentenceID: UUID) async {
        if await mutate({ next in
            guard let i = next.records.firstIndex(where: { $0.id == creationID }), let line = next.records[i].versions.first(where: { $0.id == sentenceID }) else { return false }
            next.records[i].selected[line.style.rawValue] = line.id; return true
        }) { notice = "已恢复这个版本，不消耗次数" }
    }
    public func edit(_ id: UUID) { if let record = record(id) { updateDraft(record.input) } }
    public func delete(_ id: UUID) async {
        await mutate { next in
            guard next.pending?.creationId != id else { self.errorMessage = "这份创作还在处理，请确认结果后再删除。"; return false }
            next.records.removeAll { $0.id == id }; return true
        }
    }
    public func clear() async {
        let originalDraft = draft
        if await mutate({ next in
            guard next.pending == nil else { self.errorMessage = "请先确认当前创作的结果，再清空本地内容。"; return false }
            next.records = []; next.draft = self.draft == originalDraft ? CreationInput() : self.draft; return true
        }), draft == originalDraft { updateDraft(CreationInput()) }
    }
}
