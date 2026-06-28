import Foundation

// T017 — Wraps NSFileCoordinator for iCloud-safe coordinated reads/writes (FR-015).

public struct FileCoordinatorService: Sendable {
    public init() {}

    public func coordinatedRead<T>(_ url: URL, _ body: (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { newURL in
            result = Result { try body(newURL) }
        }
        if let coordError { throw coordError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    public func coordinatedWrite(_ url: URL, _ body: (URL) throws -> Void) throws {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var thrown: Error?
        coordinator.coordinate(writingItemAt: url, options: [], error: &coordError) { newURL in
            do { try body(newURL) } catch { thrown = error }
        }
        if let coordError { throw coordError }
        if let thrown { throw thrown }
    }
}
