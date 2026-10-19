import Foundation

public enum GenerationError: LocalizedError, Equatable {
    case message(String), uncertain, processing, missing, unauthorized
    public var errorDescription: String? {
        switch self {
        case .message(let text): return text
        case .uncertain: return "暂时没连上，正在保留这次请求。请点确认结果，避免重复创作。"
        case .processing: return "还在写，稍后可以继续确认这次结果。"
        case .unauthorized: return "请先输入有效的内测邀请码。"
        case .missing: return "没有找到这次请求，原来的输入已保留。"
        }
    }
}

public protocol GenerationService: Sendable {
    var isDemo: Bool { get }
    func perform(_ operation: PendingGeneration) async throws -> GenerationReply
    func recover(_ operation: PendingGeneration) async throws -> GenerationReply
    func quota() async throws -> CreationQuota?
    var requiresInvitation: Bool { get }
    func hasAccess() async -> Bool
    func join(_ code: String) async throws
    func leave() async throws
    func feedback(category: String, note: String, creationID: UUID?) async throws
}

public extension GenerationService {
    var requiresInvitation: Bool { false }
    func hasAccess() async -> Bool { true }
    func join(_ code: String) async throws { throw GenerationError.message("当前服务不需要邀请码。") }
    func leave() async throws {}
    func feedback(category: String, note: String, creationID: UUID?) async throws { throw GenerationError.message("示例模式不发送反馈。") }
}

public struct BetaSession: Codable, Sendable {
    public var token: String
    public var expiresAt: Date
    public init(token: String, expiresAt: Date) { self.token = token; self.expiresAt = expiresAt }
}
public protocol SessionCredentials: Sendable {
    func load() async throws -> BetaSession?
    func save(_ value: BetaSession?) async throws
}
public actor MemorySessionCredentials: SessionCredentials {
    private var value: BetaSession?
    public init() {}
    public func load() -> BetaSession? { value }
    public func save(_ value: BetaSession?) { self.value = value }
}

public struct LiveGenerationService: GenerationService {
    public let isDemo = false
    public let baseURL: URL
    private let installationID: String
    private let session: URLSession
    private let credentials: any SessionCredentials
    public let requiresInvitation: Bool
    public init(baseURL: URL, installationID: String, session: URLSession = .shared, credentials: any SessionCredentials = MemorySessionCredentials(), requiresInvitation: Bool = true) {
        self.baseURL = baseURL; self.installationID = installationID; self.session = session; self.credentials = credentials; self.requiresInvitation = requiresInvitation
    }
    private struct WireInput: Encodable {
        let scene: String; let mood: String; let image: String?
        init(_ input: CreationInput) {
            scene = input.scene.trimmingCharacters(in: .whitespacesAndNewlines)
            mood = input.mood.trimmingCharacters(in: .whitespacesAndNewlines)
            image = input.imageData.map { "data:image/jpeg;base64," + $0.base64EncodedString() }
        }
    }
    private struct Body: Encodable {
        let requestId: UUID; let creationId: UUID; let input: WireInput; let style: WritingStyle?; let previous: [String]
    }
    private struct Problem: Decodable { let error: String; let code: String? }
    private struct QuotaReply: Decodable { let quota: CreationQuota }
    private var endpoint: URL { baseURL.appendingPathComponent("api/v1/generations") }
    private func request(url: URL, authenticated: Bool = true) async throws -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 70)
        request.setValue(installationID, forHTTPHeaderField: "X-Sanju-Installation")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated && requiresInvitation {
            guard let value = try await credentials.load(), value.expiresAt > Date() else { throw GenerationError.unauthorized }
            request.setValue("Bearer " + value.token, forHTTPHeaderField: "Authorization")
        }
        return request
    }
    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data; let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw GenerationError.uncertain }
        guard let http = response as? HTTPURLResponse else { throw GenerationError.uncertain }
        if http.statusCode == 401 { throw GenerationError.unauthorized }
        if http.statusCode >= 500 && http.statusCode != 502 { throw GenerationError.uncertain }
        if http.statusCode == 202 { throw GenerationError.processing }
        if http.statusCode == 404 { throw GenerationError.missing }
        guard (200..<300).contains(http.statusCode) else {
            let problem = try? JSONDecoder().decode(Problem.self, from: data)
            throw GenerationError.message(problem?.error ?? "这次没有写好，请稍后再试。")
        }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        do { return try decoder.decode(T.self, from: data) }
        catch { throw GenerationError.uncertain }
    }
    public func perform(_ operation: PendingGeneration) async throws -> GenerationReply {
        var request = try await request(url: endpoint); request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(Body(requestId: operation.requestId, creationId: operation.creationId, input: WireInput(operation.input), style: operation.style, previous: operation.previous))
        return try await send(request)
    }
    public func recover(_ operation: PendingGeneration) async throws -> GenerationReply {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "requestId", value: operation.requestId.uuidString)]
        // Recovery only looks up the original request. A missing request must
        // never turn this user action into a new paid generation.
        return try await send(try await request(url: components.url!))
    }
    public func quota() async throws -> CreationQuota? {
        let reply: QuotaReply = try await send(try await request(url: endpoint))
        return reply.quota
    }
    public func hasAccess() async -> Bool {
        guard requiresInvitation else { return true }
        guard let value = try? await credentials.load() else { return false }
        return value.expiresAt > Date()
    }
    public func join(_ code: String) async throws {
        var request = try await request(url: baseURL.appendingPathComponent("api/v1/sessions"), authenticated: false)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(["code": code.trimmingCharacters(in: .whitespacesAndNewlines)])
        let value: BetaSession = try await send(request)
        try await credentials.save(value)
    }
    private struct Acknowledgement: Decodable { let ok: Bool }
    public func leave() async throws {
        do {
            var request = try await request(url: baseURL.appendingPathComponent("api/v1/sessions"))
            request.httpMethod = "DELETE"
            let _: Acknowledgement = try await send(request)
            try await credentials.save(nil)
        } catch { try await credentials.save(nil); throw error }
    }
    public func feedback(category: String, note: String, creationID: UUID?) async throws {
        var request = try await request(url: baseURL.appendingPathComponent("api/v1/feedback"))
        request.httpMethod = "POST"
        struct Feedback: Encodable { let category: String; let note: String; let creationId: UUID? }
        request.httpBody = try JSONEncoder().encode(Feedback(category: category, note: note, creationId: creationID))
        let _: Acknowledgement = try await send(request)
    }

}

public struct DemoGenerationService: GenerationService {
    public let isDemo = true
    public init() {}
    public static let samples: [WritingStyle: [String]] = [
        .cool: ["海风照常吹过，心里的热闹却已经提前散场。", "海浪从不解释来去，岸上的人却总要一个答案。", "黄昏没有挽留谁，只是照常收起了最后的光。", "海面渐渐安静下来，有些话也就不必再说了。"],
        .romantic: ["黄昏把最后一点温柔，轻轻留在了这片海上。", "愿晚风替我收藏，这一刻还没有说完的温柔。", "海把落日轻轻托起，像在等一个迟来的拥抱。", "暮色慢慢落进海里，替今天留下一封温柔的信。"],
        .youth: ["海风把黄昏吹得很远，也把明天吹得值得期待。", "在这片海边歇一会儿，明天又有勇气继续出发。", "原来长大后的快乐，也可以只是安静看一次海。", "青春走过那么多路，终于学会陪自己看一场海。"]
    ]
    public func perform(_ operation: PendingGeneration) async throws -> GenerationReply {
        try await Task.sleep(nanoseconds: 650_000_000)
        let styles = operation.style.map { [$0] } ?? WritingStyle.allCases
        let lines = styles.map { style in
            GeneratedLine(style: style, text: Self.samples[style]!.first { !operation.previous.contains($0) } ?? Self.samples[style]![0])
        }
        return GenerationReply(creationId: operation.creationId, lines: lines, swapsRemaining: 3, expiresAt: Date().addingTimeInterval(24 * 3600))
    }
    public func recover(_ operation: PendingGeneration) async throws -> GenerationReply { try await perform(operation) }
    public func quota() async throws -> CreationQuota? { nil }
}
