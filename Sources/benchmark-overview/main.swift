// benchmark-overview CLI (US4 / T036) — print the BenchmarkEngine heat map.
// usage: benchmark-overview --workspace <path> [--as-of YYYY-MM-DD]
import Foundation
import FinanceWorkspaceKit

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8)); exit(code)
}

var workspacePath: String?
var asOf = Date()
var args = Array(CommandLine.arguments.dropFirst())
let isoDay: ISO8601DateFormatter = {
    let fmt = ISO8601DateFormatter(); fmt.formatOptions = [.withFullDate]; fmt.timeZone = TimeZone(identifier: "UTC"); return fmt
}()
let usage = "usage: benchmark-overview --workspace <path> [--as-of YYYY-MM-DD]"
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "--as-of":
        guard let raw = args.first, let date = isoDay.date(from: raw) else { fail("invalid --as-of (expected YYYY-MM-DD)", code: 2) }
        asOf = date; args.removeFirst()
    case "-h", "--help": fail(usage, code: 0)
    default: break
    }
}
guard let workspacePath else { fail(usage, code: 2) }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)

func padR(_ text: String, _ width: Int) -> String { text.count >= width ? text : text + String(repeating: " ", count: width - text.count) }
func padL(_ text: String, _ width: Int) -> String { text.count >= width ? text : String(repeating: " ", count: width - text.count) + text }
func cellText(_ growth: GrowthState) -> String {
    switch growth {
    case let .simple(value), let .cagr(value):
        let percent = NSDecimalNumber(decimal: value * 100).doubleValue
        return String(format: "%@%.1f%%", percent >= 0 ? "+" : "", percent)
    case .insufficientHistory: return "—"
    }
}
func rowText(_ label: String, _ cells: [BenchmarkCell]) -> String {
    padR(label, 18) + cells.map { padL(cellText($0.growth), 9) }.joined()
}

let context = try WorkspaceParser().parse(workspaceURL: root)
let heat = BenchmarkEngine().heatMap(context, asOf: asOf)
let iso = ISO8601DateFormatter(); iso.formatOptions = [.withFullDate]

print("Benchmark heat map — as of \(iso.string(from: asOf)) (CAGR for 3Y/5Y)")
print(padR("", 18) + BenchmarkWindow.allCases.map { padL($0.rawValue, 9) }.joined())
print(String(repeating: "─", count: 18 + 9 * BenchmarkWindow.allCases.count))
print(rowText(heat.benchmark.label, heat.benchmark.cells))
for row in heat.accounts { print(rowText(row.label, row.cells)) }
if !heat.sectorWeights.isEmpty {
    print(String(repeating: "─", count: 40))
    print("Portfolio sector weights:")
    for sector in heat.sectorWeights {
        print("  \(padR(sector.sector, 16)) \(String(format: "%.1f%%", NSDecimalNumber(decimal: sector.weight * 100).doubleValue))")
    }
}
