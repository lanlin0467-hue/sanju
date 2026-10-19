import XCTest
@testable import SanjuCore

private final class WireStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var callback: (@Sendable (URLRequest) throws -> (Int, Data))?
    static func handle(_ callback: @escaping @Sendable (URLRequest) throws -> (Int,Data)) { lock.withLock { self.callback = callback } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.lock.withLock({ Self.callback }) else { throw URLError(.unknown) }
            let (status,data) = try handler(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class LiveServiceTests: XCTestCase {
    private func service(_ vault: MemorySessionCredentials = MemorySessionCredentials()) -> LiveGenerationService {
        let config=URLSessionConfiguration.ephemeral; config.protocolClasses=[WireStub.self]
        return LiveGenerationService(baseURL: URL(string:"https://example.test")!, installationID:UUID().uuidString,session:URLSession(configuration:config),credentials:vault)
    }
    func testJoinStoresSessionAndAuthenticatesRequests() async throws {
        let vault=MemorySessionCredentials(); let service=service(vault)
        WireStub.handle { request in
            if request.url!.path.hasSuffix("sessions") {
                XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"))
                return (200,Data("{\"token\":\"test-token\",\"expiresAt\":\"2099-01-01T00:00:00Z\"}".utf8))
            }
            XCTAssertEqual(request.value(forHTTPHeaderField:"Authorization"),"Bearer test-token")
            return (200,Data("{\"quota\":{\"remaining\":5,\"resetsAt\":\"2099-01-01T00:00:00Z\"}}".utf8))
        }
        try await service.join("invitation")
        let saved=try await vault.load(); XCTAssertEqual(saved?.token,"test-token")
        let quota=try await service.quota(); XCTAssertEqual(quota?.remaining,5)
    }
    func testExpiredCredentialsDoNotSendRequests() async throws {
        let vault=MemorySessionCredentials(); await vault.save(.init(token:"expired",expiresAt:.distantPast))
        WireStub.handle { _ in XCTFail("Expired credentials must not reach the server"); return (500,Data()) }
        do { _ = try await service(vault).quota(); XCTFail("Expected authentication failure") }
        catch { XCTAssertEqual(error as? GenerationError,.unauthorized) }
    }
    func testUnavailableAndUnauthorizedAreRecoverableKinds() async throws {
        let vault=MemorySessionCredentials(); await vault.save(.init(token:"token",expiresAt:.distantFuture))
        let service=service(vault)
        for (status,expected) in [(503,GenerationError.uncertain),(401,.unauthorized)] {
            WireStub.handle { _ in (status,Data("{\"error\":\"service unavailable\"}".utf8)) }
            do { _ = try await service.quota(); XCTFail("Expected an error") }
            catch { XCTAssertEqual(error as? GenerationError,expected) }
        }
    }
    func testUnknownRequestResendsSameOperationAfterLookup() async throws {
        let vault=MemorySessionCredentials(); await vault.save(.init(token:"token",expiresAt:.distantFuture))
        let op=PendingGeneration(creationId:UUID(),input:.init(scene:"黄昏海边",mood:"平静",imageData:Data([1,2,3])))
        WireStub.handle { request in
            if request.httpMethod == "GET" {
                XCTAssertTrue(request.url!.query!.contains(op.requestId.uuidString)); return (404,Data())
            }
            XCTAssertEqual(request.httpMethod,"POST")
            XCTAssertEqual(request.value(forHTTPHeaderField:"Authorization"),"Bearer token")
            let reply=GenerationReply(creationId:op.creationId,lines:WritingStyle.allCases.map { .init(style:$0,text:DemoGenerationService.samples[$0]![0]) },swapsRemaining:3,expiresAt:.distantFuture)
            let encoder=JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            return (200,try encoder.encode(reply))
        }
        let result=try await service(vault).recover(op); XCTAssertEqual(result.creationId,op.creationId)
    }
}
