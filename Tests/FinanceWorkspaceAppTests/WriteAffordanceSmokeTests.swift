import Testing
import Foundation
@testable import FinanceWorkspaceApp
@testable import FinanceWorkspaceKit

// 008 T015 (US1 / SC-001) — no module view ships a permanently-disabled write button. Two angles:
// behavioural (the `LocalAction.write` factory is enabled whenever the gate allows writing, and
// carries a human-readable reason whenever it doesn't) and structural (the Phase-5 `writeStub`
// pattern and hardcoded `isEnabled: false` literals must never reappear in the UI sources).

@MainActor
@Suite struct WriteAffordanceSmokeTests {

    @Test func writeActionEnabledWheneverGateAllows() {
        let state = AppState()
        state.workspaceURL = URL(fileURLWithPath: "/tmp/ws")   // any open workspace
        state.syncState = .available

        let action = LocalAction.write("Add", systemImage: "plus", state: state) {}
        #expect(action.isEnabled)
        #expect(action.disabledReason == nil)
    }

    @Test func blockedWriteActionAlwaysCarriesAReason() {
        let state = AppState()
        state.workspaceURL = URL(fileURLWithPath: "/tmp/ws")

        for blocked in [SyncState.syncing, .notSignedIn, .containerUnavailable] {
            state.syncState = blocked
            let action = LocalAction.write("Add", systemImage: "plus", state: state) {}
            #expect(!action.isEnabled)
            #expect(action.disabledReason?.isEmpty == false,
                    "a disabled write affordance must explain itself (\(blocked))")
        }
        // No workspace open is also a reasoned, not silent, disable.
        state.workspaceURL = nil
        state.syncState = .available
        let action = LocalAction.write("Add", systemImage: "plus", state: state) {}
        #expect(!action.isEnabled && action.disabledReason?.isEmpty == false)
    }

    /// Structural guard: the retired Phase-5 stub patterns must not resurface anywhere in the
    /// app UI sources (SC-001 — "no permanently-disabled write button").
    @Test func noStubOrHardcodedDisableInUISources() throws {
        let uiRoot = URL(fileURLWithPath: #filePath)          // …/Tests/FinanceWorkspaceAppTests/…
            .deletingLastPathComponent()                       // Tests/FinanceWorkspaceAppTests
            .deletingLastPathComponent()                       // Tests
            .deletingLastPathComponent()                       // repo root
            .appendingPathComponent("Sources/FinanceWorkspaceApp/UI", isDirectory: true)

        var offenders: [String] = []
        let enumerator = FileManager.default.enumerator(at: uiRoot, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if text.contains("writeStub") || text.contains("isEnabled: false") {
                offenders.append(url.lastPathComponent)
            }
        }
        #expect(offenders.isEmpty, "permanently-disabled write patterns found in: \(offenders)")
    }
}
