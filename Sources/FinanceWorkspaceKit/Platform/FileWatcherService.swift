import Foundation

// T033 — Watch the workspace for file-system changes and trigger debounced, incremental re-index.
// FSEvents path for the local-folder provider. (The iCloud provider uses NSMetadataQuery — added in US3.)
// FSEvents requires an active run loop / dispatch queue, so this is exercised at app runtime.

public final class FileWatcherService: @unchecked Sendable {
    private let path: String
    private let debounce: TimeInterval
    private let onChange: @Sendable ([String]) -> Void
    private let queue = DispatchQueue(label: "app.openfinance.filewatcher")
    private var stream: FSEventStreamRef?
    private var pending: DispatchWorkItem?

    public init(workspaceRoot: URL, debounce: TimeInterval = 0.3,
                onChange: @escaping @Sendable ([String]) -> Void) {
        self.path = workspaceRoot.path
        self.debounce = debounce
        self.onChange = onChange
    }

    public func start() {
        var context = FSEventStreamContext(version: 0,
                                           info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileWatcherService>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            watcher.handle(paths: Array(paths.prefix(count)))
        }
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context,
            [path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2, FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        ) else { return }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// Coalesce rapid changes; ignore the app-managed .finance-meta subtree.
    private func handle(paths: [String]) {
        let relevant = paths.filter { !$0.contains("/.finance-meta/") }
        guard !relevant.isEmpty else { return }
        pending?.cancel()
        let work = DispatchWorkItem { [onChange] in onChange(relevant) }
        pending = work
        queue.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    deinit { stop() }
}
