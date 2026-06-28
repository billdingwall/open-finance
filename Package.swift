// swift-tools-version: 6.0
import PackageDescription

// FinanceWorkspaceApp — Phase 1 Foundation & Architecture.
// Scaffolded as a Swift Package (buildable/testable headlessly + CI-friendly).
// An Xcode app target/wrapper is added later when UI/packaging matters (Phase 5).
// Module folders from the architecture (Platform/, Domain/, Validation/, Persistence/)
// live as subdirectories of the FinanceWorkspaceKit library target.
let package = Package(
    name: "FinanceWorkspaceApp",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "FinanceWorkspaceKit"
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
        .testTarget(
            name: "FinanceWorkspaceKitTests",
            dependencies: ["FinanceWorkspaceKit"]
        ),
    ]
)
