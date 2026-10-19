import Foundation

public enum WritingStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case cool, romantic, youth
    public var id: String { rawValue }
    public var title: String {
        switch self { case .cool: return "冷峻"; case .romantic: return "浪漫"; case .youth: return "青春" }
    }
    public var subtitle: String {
        switch self { case .cool: return "克制一点，清醒一点"; case .romantic: return "让温柔有一个落点"; case .youth: return "给平常的一刻一点勇气" }
    }
}

public struct CreationInput: Codable, Hashable, Sendable {
    public var scene: String
    public var mood: String
    public var imageData: Data?
    public init(scene: String = "", mood: String = "", imageData: Data? = nil) {
        self.scene = scene; self.mood = mood; self.imageData = imageData
    }
    public var validationMessage: String? {
        if imageData == nil && scene.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "添加一张照片，或写下你看到的画面。" }
        if mood.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "再说说此刻的心情。" }
        if scene.count > 200 { return "画面描述请控制在 200 字以内。" }
        if mood.count > 30 { return "心情请控制在 30 字以内。" }
        if let imageData, imageData.count > 500 * 1024 { return "照片还没有处理好，请重新选择。" }
        return nil
    }
    public var isEmpty: Bool { scene.isEmpty && mood.isEmpty && imageData == nil }
    public var summary: String { scene.isEmpty ? "照片里的这一刻" : scene }
}

public struct SentenceVersion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var style: WritingStyle
    public var text: String
    public var createdAt: Date
    public var favoritedAt: Date?
    public var replacedAt: Date?
    public init(id: UUID = UUID(), style: WritingStyle, text: String, createdAt: Date = Date(), favoritedAt: Date? = nil) {
        self.id = id; self.style = style; self.text = text; self.createdAt = createdAt; self.favoritedAt = favoritedAt
    }
}

public struct Creation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var input: CreationInput
    public var createdAt: Date
    public var expiresAt: Date
    public var swapsRemaining: Int
    public var versions: [SentenceVersion]
    public var selected: [String: UUID]
    public var isDemo: Bool
    public init(id: UUID, input: CreationInput, createdAt: Date, expiresAt: Date, swapsRemaining: Int, versions: [SentenceVersion], isDemo: Bool) {
        self.id = id; self.input = input; self.createdAt = createdAt; self.expiresAt = expiresAt
        self.swapsRemaining = swapsRemaining; self.versions = versions; self.isDemo = isDemo
        selected = Dictionary(uniqueKeysWithValues: versions.map { ($0.style.rawValue, $0.id) })
    }
    public func current(_ style: WritingStyle) -> SentenceVersion? {
        versions.first { $0.id == selected[style.rawValue] } ?? versions.last { $0.style == style }
    }
    public var favoriteCount: Int { versions.filter { $0.favoritedAt != nil }.count }
    public func matches(_ query: String) -> Bool {
        query.isEmpty || ([input.scene, input.mood] + versions.map(\.text)).contains { $0.localizedStandardContains(query) }
    }
}

public struct CreationQuota: Codable, Equatable, Sendable {
    public var remaining: Int
    public var resetsAt: Date
    public init(remaining: Int, resetsAt: Date) { self.remaining = remaining; self.resetsAt = resetsAt }
    public static func demo(now: Date) -> Self {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return .init(remaining: 5, resetsAt: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!)
    }
}

public struct GeneratedLine: Codable, Equatable, Sendable {
    public var style: WritingStyle
    public var text: String
    public init(style: WritingStyle, text: String) { self.style = style; self.text = text }
}

public struct GenerationReply: Codable, Sendable {
    public var creationId: UUID
    public var lines: [GeneratedLine]
    public var swapsRemaining: Int
    public var expiresAt: Date
    public var quota: CreationQuota?
    public init(creationId: UUID, lines: [GeneratedLine], swapsRemaining: Int, expiresAt: Date, quota: CreationQuota? = nil) {
        self.creationId = creationId; self.lines = lines; self.swapsRemaining = swapsRemaining; self.expiresAt = expiresAt; self.quota = quota
    }
}

public struct PendingGeneration: Codable, Equatable, Sendable {
    public var requestId: UUID
    public var creationId: UUID
    public var input: CreationInput
    public var style: WritingStyle?
    public var previous: [String]
    public var startedAt: Date
    public init(requestId: UUID = UUID(), creationId: UUID, input: CreationInput, style: WritingStyle? = nil, previous: [String] = [], startedAt: Date = Date()) {
        self.requestId = requestId; self.creationId = creationId; self.input = input; self.style = style; self.previous = previous; self.startedAt = startedAt
    }
}

public struct LibraryState: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var records: [Creation] = []
    public var draft = CreationInput()
    public var draftUpdatedAt: Date?
    public var quota: CreationQuota?
    public var pending: PendingGeneration?
    public var consentVersion: String?
    public init() {}
}
