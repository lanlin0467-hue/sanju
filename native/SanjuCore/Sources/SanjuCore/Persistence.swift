import Foundation

// Implementations are accessed by LibraryStorage, outside the UI actor.
public protocol LibraryPersistence: Sendable {
    func load() throws -> LibraryState
    func save(_ state: LibraryState) throws
}

actor LibraryStorage {
    private let persistence: any LibraryPersistence
    init(_ persistence: any LibraryPersistence) { self.persistence = persistence }
    func load() throws -> LibraryState { try persistence.load() }
    func save(_ state: LibraryState) throws { try persistence.save(state) }
}

public struct FileLibraryPersistence: LibraryPersistence {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> LibraryState {
        guard FileManager.default.fileExists(atPath: url.path) else { return LibraryState() }
        let state = try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: url))
        guard state.schemaVersion == 1 else { throw CocoaError(.coderReadCorrupt) }
        return state
    }
    public func save(_ state: LibraryState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
