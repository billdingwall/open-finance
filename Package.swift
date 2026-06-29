// swift-tools-version: 6.0
import PackageDescription

// FinanceWorkspaceApp — Phases 1–2 (Foundation; Parsing, Validation & Infrastructure).
// Scaffolded as a Swift Package (buildable/testable headlessly + CI-friendly).
// An Xcode app target/wrapper is added later when UI/packaging matters (Phase 5).
// Module folders from the architecture (Platform/, Parsing/, Validation/, Persistence/, Domain/)
// live as subdirectories of the FinanceWorkspaceKit library target.
let package = Package(
    name: "FinanceWorkspaceApp",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "FinanceWorkspaceKit",
            // Canonical JSON schemas are bundled with the app (authoritative at runtime via
            // Bundle.module); bootstrap mirrors them into the workspace .finance-meta/schemas/.
            resources: [.copy("Resources/Schemas")]
        ),
        .executableTarget(
            name: "FinanceWorkspaceApp",
            dependencies: ["FinanceWorkspaceKit"]
        ),
        .executableTarget(
            name: "bootstrap-workspace",
            dependencies: ["FinanceWorkspaceKit"]
        ),
        .executableTarget(
            name: "fixture-generate",
            dependencies: ["FinanceWorkspaceKit"]
        ),
        .executableTarget(
            name: "index-check",
            dependencies: ["FinanceWorkspaceKit"]
        ),
        .executableTarget(
            name: "validate-workspace",
            dependencies: ["FinanceWorkspaceKit"]
        ),
        .executableTarget(
            name: "repair-workspace",
            dependencies: ["FinanceWorkspaceKit"]
        ),
        .executableTarget(
            name: "migrate-r6",
            dependencies: ["FinanceWorkspaceKit"]
        ),
        .testTarget(
            name: "FinanceWorkspaceKitTests",
            dependencies: ["FinanceWorkspaceKit"]
        ),
    ]
)
