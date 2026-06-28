import Foundation
import os

// FR-025 — Foundation-level diagnostics go to the macOS unified log (os.Logger).
// Workspace .finance-meta/logs/ files stay reserved for user-facing audit (repair/import).

public enum Diagnostics {
    public static let subsystem = "app.openfinance.FinanceWorkspace"

    public static let workspace = Logger(subsystem: subsystem, category: "workspace")
    public static let index = Logger(subsystem: subsystem, category: "index")
    public static let sync = Logger(subsystem: subsystem, category: "sync")
}
