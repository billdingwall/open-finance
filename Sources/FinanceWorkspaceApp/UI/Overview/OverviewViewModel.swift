import Foundation
import FinanceWorkspaceKit

// T032 — Overview presentation mapper (FR-015/016): `OverviewDashboard` → 5 KPI card models
// (typed states preserved), the MoM sparkline series, and severity-grouped issue rows.
// Formatting/grouping only — every figure passes through from the engine untouched (FR-031).

struct OverviewViewModel {
    let dashboard: OverviewDashboard

    // MARK: - KPI cards

    /// The five cards, in the engine's order, mapped to the fixed route table
    /// (contracts/app-shell.md). Typed states render as designed text, never zeros.
    func cards(projections: WorkspaceProjections?) -> [KPICardModel] {
        dashboard.cards.map { card in
            let route = AppRouter.route(forKPI: card.kind, in: projections)
            guard card.state == .available else {
                return KPICardModel(id: card.kind, overline: title(card.kind), value: "—",
                                    typedState: TypedStateText.dataNotAvailable, route: route)
            }
            return KPICardModel(
                id: card.kind,
                overline: title(card.kind),
                value: card.value.map(Format.money) ?? "—",
                secondary: secondary(card),
                delta: nil,
                typedState: nil,
                route: route,
                footnote: footnote(card))
        }
    }

    private func title(_ kind: String) -> String {
        switch kind {
        case "budget": return "Budget"
        case "savings": return "Savings"
        case "investments": return "Investments"
        case "business": return "Business"
        case "taxes": return "Taxes"
        default: return kind.capitalized
        }
    }

    private func secondary(_ card: OverviewSummaryCard) -> String? {
        guard let secondary = card.secondaryValue else { return nil }
        switch card.kind {
        case "budget": return "spent \(Format.money(secondary))"
        case "savings": return "+\(Format.money(secondary))/mo"
        case "taxes": return "paid \(Format.money(secondary))"
        default: return Format.money(secondary)
        }
    }

    private func footnote(_ card: OverviewSummaryCard) -> String? {
        switch card.estimatedRate {
        case .value(let rate): return "est. rate \(Format.percent(rate))"
        case .rateNotSet: return TypedStateText.rateNotSet
        case nil: return card.kind == "taxes" ? "estimated return" : nil
        }
    }

    // MARK: - Month-over-month

    var momPoints: [SparkPoint] {
        dashboard.monthOverMonth.map { SparkPoint(period: $0.period, value: $0.netIncome) }
    }

    // MARK: - Issues (severity groups, repairable badge)

    struct IssueGroup: Identifiable {
        var severity: ValidationSeverity
        var issues: [ValidationIssue]
        var id: String { severity.rawValue }
    }

    /// Errors first, then warnings, then info; empty groups dropped.
    var issueGroups: [IssueGroup] {
        [ValidationSeverity.error, .warning, .info].compactMap { severity in
            let matching = dashboard.issues.filter { $0.severity == severity }
            return matching.isEmpty ? nil : IssueGroup(severity: severity, issues: matching)
        }
    }

    var issueCount: Int { dashboard.issues.count }
}
