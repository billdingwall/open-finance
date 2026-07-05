import Foundation
import Testing
@testable import FinanceWorkspaceApp
import FinanceWorkspaceKit

// T033 — Overview mapping: card typed states (incl. "rate not set"), MoM passthrough, and
// issue grouping whose total equals the header chip count.

@Suite struct OverviewViewModelTests {

    private func makeDashboard(cards: [OverviewSummaryCard],
                               mom: [MonthlySnapshot] = [],
                               issues: [ValidationIssue] = []) -> OverviewDashboard {
        OverviewDashboard(asOfMonth: "2026-06", cards: cards, monthOverMonth: mom, issues: issues)
    }

    @Test func rateNotSetRendersAsFootnoteTypedText() {
        let dashboard = makeDashboard(cards: [
            OverviewSummaryCard(kind: "investments", state: .available, value: 1000,
                                estimatedRate: .rateNotSet),
            OverviewSummaryCard(kind: "savings", state: .available, value: 500,
                                estimatedRate: .value(0.042)),
        ])
        let cards = OverviewViewModel(dashboard: dashboard).cards(projections: nil)

        #expect(cards[0].footnote == TypedStateText.rateNotSet)
        #expect(cards[0].value == Format.money(1000))         // value passes through untouched
        #expect(cards[1].footnote == "est. rate 4.2%")
    }

    @Test func unavailableCardRendersTypedStateNeverZero() {
        let dashboard = makeDashboard(cards: [.unavailable("budget")])
        let cards = OverviewViewModel(dashboard: dashboard).cards(projections: nil)

        #expect(cards[0].typedState == TypedStateText.dataNotAvailable)
        #expect(cards[0].value != Format.money(0))
    }

    @Test func momSeriesPassesThroughInOrder() {
        let dashboard = makeDashboard(cards: [], mom: [
            MonthlySnapshot(period: "2026-04", netIncome: 100),
            MonthlySnapshot(period: "2026-06", netIncome: 300),   // gap-skipped series kept as-is
        ])
        let points = OverviewViewModel(dashboard: dashboard).momPoints

        #expect(points.map(\.period) == ["2026-04", "2026-06"])
        #expect(points.map(\.value) == [100, 300])
    }

    @Test func issueGroupingMatchesChipCount() {
        func issue(_ rule: String, _ severity: ValidationSeverity) -> ValidationIssue {
            ValidationIssue(ruleId: rule, tier: .file, severity: severity, repairClass: .none,
                            message: "m", filePath: "f.csv")
        }
        let dashboard = makeDashboard(cards: [], issues: [
            issue("VAL-FILE-001", .warning), issue("VAL-FILE-002", .error), issue("VAL-FILE-003", .error),
        ])
        let viewModel = OverviewViewModel(dashboard: dashboard)

        #expect(viewModel.issueGroups.map(\.severity) == [.error, .warning])   // errors first
        #expect(viewModel.issueGroups.flatMap(\.issues).count == viewModel.issueCount)
    }
}
