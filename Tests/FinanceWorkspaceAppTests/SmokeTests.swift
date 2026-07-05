import Testing
@testable import FinanceWorkspaceApp

// T001 — target smoke test; real suites arrive with each user story.
@Suite struct SmokeTests {
    @Test func targetLinks() {
        #expect(Bool(true))
    }
}
