import Foundation
import FinanceWorkspaceKit

// T010/T011/T014 — the typed navigation model: `Route` (where the user is), the
// `NSUserActivity` codec (research D6), and the router (sidebar/KPI navigation, stale-ID
// fallback). Session selectors are deliberately NOT encoded (clarify Q1 — session-only).

enum BudgetSubview: String, CaseIterable, Sendable {
    case overview, history, categories
}

enum SISubview: String, CaseIterable, Sendable {
    case overview, goals, portfolio
}

enum TaxSubview: String, CaseIterable, Sendable {
    case currentYear = "current-year"
    case prepChecklist = "prep-checklist"
    case archive
}

/// The single typed description of the user's location (data-model.md).
enum Route: Hashable, Sendable {
    case overview
    case accounts
    case accountGroup(String)
    case account(String)
    case budget(BudgetSubview)
    case savingsInvestments(SISubview)
    case goal(String)
    case holding(String)
    case taxes(TaxSubview)

    /// The module a route belongs to — drives breadcrumbs and stale-ID fallback.
    var parentModule: Route {
        switch self {
        case .overview: return .overview
        case .accounts, .accountGroup, .account: return .accounts
        case .budget: return .budget(.overview)
        case .savingsInvestments, .goal, .holding: return .savingsInvestments(.overview)
        case .taxes: return .taxes(.currentYear)
        }
    }
}

// MARK: - NSUserActivity codec (D6)

/// Versioned dictionary payload for state restoration. Only module + entity restore across
/// relaunch; in-module selector state is session-only.
enum RouteActivityCodec {
    static let activityType = "app.openfinance.navigation"
    private static let version = 1

    static func encode(_ route: Route, paneOpen: Bool = false) -> [String: String] {
        var payload = ["v": String(version), "paneOpen": paneOpen ? "1" : "0"]
        switch route {
        case .overview: payload["module"] = "overview"
        case .accounts: payload["module"] = "accounts"
        case .accountGroup(let id): payload["module"] = "accounts"; payload["group"] = id
        case .account(let id): payload["module"] = "accounts"; payload["account"] = id
        case .budget(let sub): payload["module"] = "budget"; payload["sub"] = sub.rawValue
        case .savingsInvestments(let sub): payload["module"] = "si"; payload["sub"] = sub.rawValue
        case .goal(let id): payload["module"] = "si"; payload["goal"] = id
        case .holding(let id): payload["module"] = "si"; payload["holding"] = id
        case .taxes(let sub): payload["module"] = "taxes"; payload["sub"] = sub.rawValue
        }
        return payload
    }

    static func decode(_ payload: [String: String]) -> Route? {
        guard payload["v"] == String(version), let module = payload["module"] else { return nil }
        switch module {
        case "overview": return .overview
        case "accounts": return decodeAccounts(payload)
        case "budget": return .budget(payload["sub"].flatMap(BudgetSubview.init(rawValue:)) ?? .overview)
        case "si": return decodeSavingsInvestments(payload)
        case "taxes": return .taxes(payload["sub"].flatMap(TaxSubview.init(rawValue:)) ?? .currentYear)
        default: return nil
        }
    }

    private static func decodeAccounts(_ payload: [String: String]) -> Route {
        if let id = payload["group"] { return .accountGroup(id) }
        if let id = payload["account"] { return .account(id) }
        return .accounts
    }

    private static func decodeSavingsInvestments(_ payload: [String: String]) -> Route {
        if let id = payload["goal"] { return .goal(id) }
        if let id = payload["holding"] { return .holding(id) }
        return .savingsInvestments(payload["sub"].flatMap(SISubview.init(rawValue:)) ?? .overview)
    }
}

// MARK: - Router

/// Pure routing logic over `AppState` — navigation, KPI mapping, stale-entity fallback.
@MainActor
struct AppRouter {
    let state: AppState

    /// Navigate, validating entity routes against the current snapshot (stale-ID fallback to
    /// the parent module) and closing the detail pane (a new context invalidates the old
    /// selection — edge-case rule).
    func navigate(to route: Route) {
        let resolved = Self.resolve(route, in: state.projections)
        if state.route != resolved { state.detailPane = DetailPaneState() }
        state.route = resolved
    }

    /// KPI card → module route (contracts/app-shell.md fixed table).
    func route(forKPI kind: String) -> Route {
        Self.route(forKPI: kind, in: state.projections)
    }

    nonisolated static func route(forKPI kind: String, in projections: WorkspaceProjections?) -> Route {
        switch kind {
        case "budget": return .budget(.overview)
        case "savings": return .savingsInvestments(.goals)
        case "investments": return .savingsInvestments(.portfolio)
        case "taxes": return .taxes(.currentYear)
        case "business": return businessRoute(in: projections)
        default: return .overview
        }
    }

    /// The Business card opens its group screen when there's exactly one business group, else
    /// the Accounts grid.
    private nonisolated static func businessRoute(in projections: WorkspaceProjections?) -> Route {
        let groups = projections?.accounts.groups.filter { $0.groupType == .business } ?? []
        if groups.count == 1, let only = groups.first {
            return .accountGroup(only.accountGroupId)
        }
        return .accounts
    }

    /// Entity routes whose ID no longer resolves fall back to the parent module (never crash).
    nonisolated static func resolve(_ route: Route, in projections: WorkspaceProjections?) -> Route {
        guard let projections else { return route }
        switch route {
        case .accountGroup(let id):
            return projections.accounts.groups.contains { $0.accountGroupId == id } ? route : route.parentModule
        case .account(let id):
            return projections.accounts.accounts.contains { $0.accountId == id } ? route : route.parentModule
        case .goal(let id):
            return projections.goals.contains { $0.goalId == id } ? route : route.parentModule
        case .holding(let id):
            return projections.holdings.positions.contains { $0.assetId == id } ? route : route.parentModule
        default:
            return route
        }
    }
}
