import Foundation
import FinanceWorkspaceKit

// Developer diagnostic: scan a workspace and print the index summary. Lets the file index be
// exercised from the command line (a precursor to the planned validate-workspace script).

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: index-check --workspace <path-to-Finance>\n".utf8))
    exit(2)
}

var workspacePath: String?
var save = false
var args = Array(CommandLine.arguments.dropFirst())
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--workspace": workspacePath = args.first; if workspacePath != nil { args.removeFirst() }
    case "--save": save = true
    default: break
    }
}
guard let workspacePath else { usage() }
let root = URL(fileURLWithPath: workspacePath, isDirectory: true)

let manifest = FileIndexService().scan(workspaceRoot: root)
let byDomain = Dictionary(grouping: manifest.files, by: \.domain).mapValues(\.count)
let errors = manifest.files.filter { $0.validationStatus == .error }
let metaLeaks = manifest.files.filter { $0.path.contains(".finance-meta") }

print("indexed files: \(manifest.files.count)")
print("by domain: \(byDomain.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: ", "))")
print(".finance-meta entries (must be 0): \(metaLeaks.count)")
print("error records: \(errors.count)\(errors.isEmpty ? "" : " -> " + errors.map(\.path).joined(separator: ", "))")
if let accounts = manifest.files.first(where: { $0.path == "Accounts/accounts.csv" }) {
    print("Accounts/accounts.csv: rows=\(accounts.rowCount) schema_version=\(accounts.schemaVersion) hash=\(accounts.hash.prefix(20))…")
}

if save {
    let store = ManifestStore()
    do {
        try store.save(manifest)
        print("manifest saved: \(store.manifestURL(workspaceId: manifest.workspaceId).path)")
    } catch {
        FileHandle.standardError.write(Data("failed to save manifest: \(error)\n".utf8))
        exit(1)
    }
}
