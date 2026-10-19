import XCTest
import Observation
@testable import SanjuCore

private final class MemoryPersistence: LibraryPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var stored = LibraryState()
    private var shouldFail = false
    private var failureIndex: Int?
    private var writes = 0
    private var loadWasMain = false
    private var saveWasMain = false
    private var gate: DispatchSemaphore?
    private var started: (@Sendable () -> Void)?
    var value: LibraryState { get { lock.withLock { stored } } set { lock.withLock { stored = newValue } } }
    var failSave: Bool { get { lock.withLock { shouldFail } } set { lock.withLock { shouldFail = newValue } } }
    var failAtSave: Int? { get { lock.withLock { failureIndex } } set { lock.withLock { failureIndex = newValue } } }
    var saveCount: Int { lock.withLock { writes } }
    var accessedOnMain: Bool { lock.withLock { loadWasMain || saveWasMain } }
    func blockNextSave(gate: DispatchSemaphore, started: @escaping @Sendable () -> Void) {
        lock.withLock { self.gate = gate; self.started = started }
    }
    func load() throws -> LibraryState { lock.withLock { loadWasMain = loadWasMain || Thread.isMainThread; return stored } }
    func save(_ state: LibraryState) throws {
        let (fail, gate, started) = lock.withLock {
            writes += 1; saveWasMain = saveWasMain || Thread.isMainThread
            let snapshot = (shouldFail || failureIndex == writes, self.gate, self.started)
            self.gate = nil; self.started = nil
            return snapshot
        }
        started?()
        if let gate { _ = gate.wait(timeout: .now() + 5) }
        if fail { throw CocoaError(.fileWriteOutOfSpace) }
        lock.withLock { stored = state }
    }
}

private struct StubService: GenerationService {
    let isDemo = true
    var fail: GenerationError?
    func quota() async throws -> CreationQuota? { nil }
    func recover(_ operation: PendingGeneration) async throws -> GenerationReply { try await perform(operation) }
    func perform(_ operation: PendingGeneration) async throws -> GenerationReply {
        if let fail { throw fail }
        let styles = operation.style.map { [$0] } ?? WritingStyle.allCases
        return GenerationReply(creationId: operation.creationId, lines: styles.map { style in
            GeneratedLine(style: style, text: DemoGenerationService.samples[style]!.first { !operation.previous.contains($0) }!)
        }, swapsRemaining: 3, expiresAt: Date().addingTimeInterval(24 * 3600))
    }
}

final class AppStoreTests: XCTestCase {
    @MainActor func testCreateReplaceRestoreAndFavoriteSurviveReload() async throws {
        let disk = MemoryPersistence()
        let store = await AppStore(persistence: disk, service: StubService())
        store.updateDraft(.init(scene: "黄昏海边", mood: "平静", imageData: Data([1,2,3])))
        let createdID = await store.startCreation()
        let id = try XCTUnwrap(createdID)
        let original = try XCTUnwrap(store.record(id)?.current(.cool))
        await store.toggleFavorite(creationID: id, sentenceID: original.id)
        await store.replace(id, style: .cool)
        let changed = try XCTUnwrap(store.record(id)?.current(.cool))
        XCTAssertNotEqual(original.text, changed.text)
        XCTAssertEqual(store.record(id)?.swapsRemaining, 2)
        XCTAssertNotNil(store.record(id)?.versions.first(where: { $0.id == original.id })?.replacedAt)
        XCTAssertEqual(store.state.quota?.remaining, 4)
        XCTAssertEqual(store.record(id)?.versions.first(where: { $0.id == original.id })?.favoritedAt != nil, true)
        await store.selectVersion(creationID: id, sentenceID: original.id)
        let restored = await AppStore(persistence: disk, service: StubService())
        XCTAssertEqual(restored.record(id)?.current(.cool)?.id, original.id)
        XCTAssertEqual(restored.record(id)?.versions.count, 4)
        XCTAssertEqual(restored.record(id)?.input.imageData, Data([1,2,3]))
        XCTAssertEqual(restored.state.quota?.remaining, 4)
    }
    @MainActor func testFailedGenerationKeepsDraftAndQuota() async {
        let store = await AppStore(persistence: MemoryPersistence(), service: StubService(fail: .message("写手暂时不可用")))
        store.updateDraft(.init(scene: "咖啡", mood: "开心"))
        _ = await store.startCreation()
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertEqual(store.draft.scene, "咖啡")
        XCTAssertEqual(store.state.quota?.remaining, 5)
        XCTAssertNil(store.pending)
        XCTAssertEqual(store.failedOperation?.input.scene, "咖啡")
        XCTAssertEqual(store.failureDescription, "写手暂时不可用")
    }
    @MainActor func testUnknownResultRemainsRecoverableAndBlocksNewCreation() async {
        let disk = MemoryPersistence()
        let store = await AppStore(persistence: disk, service: StubService(fail: .uncertain))
        store.updateDraft(.init(scene: "海边", mood: "期待"))
        _ = await store.startCreation()
        let pending = store.pending
        _ = await store.startCreation()
        XCTAssertEqual(store.pending, pending)
        let recovered = await AppStore(persistence: disk, service: StubService())
        await recovered.recover()
        XCTAssertEqual(recovered.records.count, 1)
        XCTAssertNil(recovered.pending)
        XCTAssertEqual(recovered.state.quota?.remaining, 4)
    }
    @MainActor func testPersistenceFailureDoesNotPretendFavoriteWasSaved() async throws {
        let disk = MemoryPersistence(); let store = await AppStore(persistence: disk, service: StubService())
        store.updateDraft(.init(scene: "雨后街角", mood: "平静"))
        let createdID = await store.startCreation()
        let id = try XCTUnwrap(createdID)
        let sentence = try XCTUnwrap(store.record(id)?.current(.cool))
        disk.failSave = true
        await store.toggleFavorite(creationID: id, sentenceID: sentence.id)
        XCTAssertNil(store.record(id)?.current(.cool)?.favoritedAt)
        XCTAssertNotNil(store.errorMessage)
    }
    @MainActor func testDeleteDoesNotRestoreQuotaAndExpiredRecordCannotSwap() async throws {
        let disk = MemoryPersistence(); let store = await AppStore(persistence: disk, service: StubService())
        store.updateDraft(.init(scene: "海边", mood: "平静"))
        let createdID = await store.startCreation()
        let id = try XCTUnwrap(createdID)
        let future = await AppStore(persistence: disk, service: StubService(), now: { Date().addingTimeInterval(25 * 3600) })
        XCTAssertFalse(future.canSwap(try XCTUnwrap(future.record(id))))
        await store.delete(id)
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertEqual(store.state.quota?.remaining, 4)
    }
    @MainActor func testGeneratedTextRemainsVisibleWhenDiskIsFullAndCanBeRecovered() async throws {
        let disk = MemoryPersistence(); let store = await AppStore(persistence: disk, service: StubService())
        store.updateDraft(.init(scene: "海边", mood: "平静"))
        disk.failAtSave = disk.saveCount + 2
        let createdID = await store.startCreation()
        let id = try XCTUnwrap(createdID)
        XCTAssertNotNil(store.record(id)?.current(.cool))
        XCTAssertFalse(store.isSaved(id))
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertNotNil(store.pending)
        disk.failAtSave = nil
        await store.recover()
        XCTAssertTrue(store.isSaved(id))
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.state.quota?.remaining, 4)
    }
    @MainActor func testAuthenticationLossKeepsOriginalPendingRequestForRecovery() async {
        let disk = MemoryPersistence()
        let store = await AppStore(persistence: disk, service: StubService(fail: .unauthorized))
        store.updateDraft(.init(scene: "海边", mood: "平静"))
        _ = await store.startCreation()
        XCTAssertNotNil(store.pending)
        XCTAssertFalse(store.hasAccess)
        let originalID = store.pending?.requestId
        let recovered = await AppStore(persistence: disk, service: StubService())
        XCTAssertEqual(recovered.pending?.requestId, originalID)
        await recovered.recover()
        XCTAssertEqual(recovered.records.count, 1)
        XCTAssertNil(recovered.pending)
    }
    @MainActor func testTypingIsDebouncedAndDraftSaveDoesNotInvalidateLibrary() async {
        let disk = MemoryPersistence(); let store = await AppStore(persistence: disk, service: StubService())
        let changed = expectation(description: "Draft saves must not invalidate record observers")
        changed.isInverted = true
        withObservationTracking { _ = store.records } onChange: { changed.fulfill() }
        for index in 0..<25 { store.updateDraft(.init(scene: "雨后的街角\(index)", mood: "平静")) }
        XCTAssertEqual(disk.saveCount, 0)
        XCTAssertEqual(store.draft.scene, "雨后的街角24")
        await store.flushDraft()
        XCTAssertEqual(disk.saveCount, 1)
        XCTAssertEqual(disk.value.draft.scene, "雨后的街角24")
        XCTAssertFalse(disk.accessedOnMain)
        await fulfillment(of: [changed], timeout: 0.1)
    }
    @MainActor func testSlowDiskLeavesMainActorFreeAndSerializesDraftAndFavorite() async throws {
        let disk = MemoryPersistence(); let store = await AppStore(persistence: disk, service: StubService())
        store.updateDraft(.init(scene: "海边", mood: "平静"))
        let createdID = await store.startCreation()
        let id = try XCTUnwrap(createdID)
        let line = try XCTUnwrap(store.record(id)?.current(.cool))
        let gate = DispatchSemaphore(value: 0)
        let started = expectation(description: "Background write started")
        disk.blockNextSave(gate: gate) { started.fulfill() }
        store.updateDraft(.init(scene: "第一版草稿", mood: "平静"))
        let saving = Task { await store.flushDraft() }
        await fulfillment(of: [started], timeout: 2)
        // This runs on the UI actor while disk I/O is deliberately blocked.
        let latest = CreationInput(scene: "保存期间继续输入的内容", mood: "期待")
        store.updateDraft(latest)
        XCTAssertEqual(store.draft, latest)
        XCTAssertFalse(disk.accessedOnMain)
        let favorite = Task { await store.toggleFavorite(creationID: id, sentenceID: line.id) }
        let newestDraft = Task { await store.flushDraft() }
        gate.signal()
        _ = await saving.value; await favorite.value; _ = await newestDraft.value
        let restored = await AppStore(persistence: disk, service: StubService())
        XCTAssertEqual(restored.draft, latest)
        XCTAssertNotNil(restored.record(id)?.current(.cool)?.favoritedAt)
        XCTAssertFalse(disk.accessedOnMain)
    }
    @MainActor func testConcurrentCreationStartsOnlyOneRequest() async {
        let disk = MemoryPersistence(); let service = CountingService()
        let store = await AppStore(persistence: disk, service: service)
        store.updateDraft(.init(scene: "海边", mood: "平静"))
        async let first = store.startCreation()
        async let second = store.startCreation()
        _ = await (first, second)
        let calls = await service.calls
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.quota?.remaining, 4)
    }
    @MainActor func testDraftEditedDuringGenerationIsPreserved() async {
        let disk = MemoryPersistence(); let service = CountingService()
        let store = await AppStore(persistence: disk, service: service)
        store.updateDraft(.init(scene: "海边", mood: "平静"))
        let creating = Task { await store.startCreation() }
        while await service.calls == 0 { await Task.yield() }
        let latest = CreationInput(scene: "下一次创作的街角", mood: "期待")
        store.updateDraft(latest)
        _ = await creating.value
        await store.flushDraft()
        let restored = await AppStore(persistence: disk, service: StubService())
        XCTAssertEqual(restored.draft, latest)
        XCTAssertEqual(restored.records.first?.input.scene, "海边")
    }
    @MainActor func testSwapFailureRetainsCurrentFavoriteAndReportsCorrectCard() async throws {
        let disk = MemoryPersistence()
        let store = await AppStore(persistence: disk, service: StubService())
        store.updateDraft(.init(scene: "海边", mood: "平静"))
        let createdID = await store.startCreation()
        let id = try XCTUnwrap(createdID)
        let line = try XCTUnwrap(store.record(id)?.current(.cool))
        await store.toggleFavorite(creationID: id, sentenceID: line.id)
        let failed = await AppStore(persistence: disk, service: StubService(fail: .message("模型暂时不可用")))
        await failed.replace(id, style: .cool)
        XCTAssertEqual(failed.record(id)?.current(.cool)?.id, line.id)
        XCTAssertNotNil(failed.record(id)?.current(.cool)?.favoritedAt)
        XCTAssertEqual(failed.record(id)?.swapsRemaining, 3)
        XCTAssertNil(failed.pending)
        XCTAssertEqual(failed.failedOperation?.style, .cool)
        XCTAssertEqual(failed.failedOperation?.creationId, id)
    }
    func testExistingLibraryWithoutReplacementDatesStillLoads() throws {
        let line = SentenceVersion(style: .cool, text: "旧版收藏", favoritedAt: Date())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(line)) as? [String: Any])
        object.removeValue(forKey: "replacedAt")
        let restored = try JSONDecoder().decode(SentenceVersion.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(restored.id, line.id)
        XCTAssertEqual(restored.favoritedAt, line.favoritedAt)
        XCTAssertNil(restored.replacedAt)
    }
    func testAtomicFileRoundTripAndCorruptionIsReported() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let disk = FileLibraryPersistence(url: directory.appendingPathComponent("library.json"))
        var state = LibraryState(); state.draft = .init(scene: "雨", mood: "平静", imageData: Data([4,5]))
        try disk.save(state)
        XCTAssertEqual(try disk.load().draft, state.draft)
        try Data("broken".utf8).write(to: disk.url)
        XCTAssertThrowsError(try disk.load())
        XCTAssertEqual(try String(contentsOf: disk.url), "broken")
    }
}

private actor CountingService: GenerationService {
    nonisolated let isDemo = true
    private(set) var calls = 0
    func quota() async throws -> CreationQuota? { nil }
    func recover(_ operation: PendingGeneration) async throws -> GenerationReply { try await perform(operation) }
    func perform(_ operation: PendingGeneration) async throws -> GenerationReply {
        calls += 1
        try await Task.sleep(for: .milliseconds(80))
        return try await StubService().perform(operation)
    }
}
