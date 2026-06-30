// overview-dashboard CLI (US3 / T033) — print the composed Overview projection for a workspace.
// usage: overview-dashboard --workspace <path> [--as-of YYYY-MM-DD]
import Foundation
import FinanceWorkspaceKit

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(code)
}
func money(_ value: Decimal?) -> String {
    guard let value else { return "—" }
    let num = NSDecimalNumber(decimal: value)
    return String(format: "%@%.2f", value < 0 ? "-" : "", abs(num.doubleValue))
}

let isoDay: ISO8601DateFormatter = {
    let fmt = ISO8601DateFormatter(); fmt.formatOptions = [.withFullDate]; fmt.timeZone = TimeZone(identifier: "UTC"); return fmt
}()

var workspacePath: String?
var asOf = Date()
var args = Array(CommandLine.arguments.dropFirst())
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "--as-of":
        guard let raw = args.first, let date = isoDay.date(from: raw) else { fail("invalid --as-of", code: 2) }
        asOf = date; args.removeFirst()
    case "-h", "--help": fail("usage: overview-dashboard --workspace <path> [--as-of YYYY-MM-DD]", code: 0)
    default: break
    }
}
guard let workspacePath else { fail("usage: overview-dashboard --workspace <path> [--as-of YYYY-MM-DD]", code: 2) }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)

do {
    let context = try WorkspaceParser().parse(workspaceURL: root)
    let settings = (try? SettingsStore().read(workspaceURL: root)) ?? .defaults()
    let dashboard = OverviewEngine().dashboard(context, asOf: asOf, settings: settings)

    print("Overview — as of \(dashboard.asOfMonth)")
    print(String(repeating: "─", count: 60))
    for card in dashboard.cards {
        if card.state == .available {
            let secondary = card.secondaryValue.map { " / \(money($0))" } ?? ""
            print("  \(card.kind.uppercased()): \(money(card.value))\(secondary)")
        } else {
            print("  \(card.kind.uppercased()): data not available")
        }
    }
    print(String(repeating: "─", count: 60))
    print("Month-over-month net income (trailing 6, populated only):")
    if dashboard.monthOverMonth.isEmpty {
        print("  (no data)")
    } else {
        for snapshot in dashboard.monthOverMonth { print("  \(snapshot.period): \(money(snapshot.netIncome))") }
    }
    print(String(repeating: "─", count: 60))
    let errors = dashboard.issues.filter { $0.severity == .error }.count
    let warnings = dashboard.issues.filter { $0.severity == .warning }.count
    print("Issues: \(errors) error, \(warnings) warning, \(dashboard.issues.count) total")
} catch {
    fail("overview-dashboard failed: \(error)", code: 1)
}
