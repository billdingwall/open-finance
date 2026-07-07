import SwiftUI
import FinanceWorkspaceKit

// First-launch onboarding behaviour on AppState (008 US5 / T045 — require-iCloud onboarding).
// The wizard owns workspace creation (Step 1) and the first group/account writes (Steps 2–3);
// every write still routes through the Kit safe-write path (WritePlanBuilder → WriteService →
// backup → atomic apply → re-index) — onboarding renders its own inline preview, it never
// bypasses the engine.

/// Step 1's iCloud/workspace-provisioning state (drives the status-chip semantics).
enum OnboardingCloudStatus: Equatable {
    case pending                 // not yet attempted
    case working                 // provisioning in flight
    case success(path: String)   // workspace created/validated at this path
    case failure(reason: String) // iCloud off / signed out / consent denied — retryable
}

@MainActor
extension AppState {

    /// True first launch = onboarding never completed AND no usable workspace at the resolved
    /// location. An existing workspace (upgrade / reinstall) skips the wizard permanently.
    /// Returns whether the caller should stop (the wizard now owns workspace creation).
    func routeFirstLaunchToOnboarding() async -> Bool {
        let defaults = UserDefaults.standard
        let forced = ProcessInfo.processInfo.environment["OPENFINANCE_FORCE_ONBOARDING"] == "1"
        guard forced || !defaults.bool(forKey: AppConfig.onboardingCompleteKey) else { return false }

        if !forced, let probe = try? await manager.openWorkspace(provisionIfMissing: false),
           probe.availability == .available {
            // Workspace already exists and validates — not a first launch.
            defaults.set(true, forKey: AppConfig.onboardingCompleteKey)
            return false
        }

        syncState = provider.syncState
        showingOnboarding = true
        return true
    }

    /// Step 1 — create the dedicated iCloud Drive folder (CloudDocs) / container workspace,
    /// bootstrap the file tree, and build the first snapshot. Retryable on failure.
    func onboardingProvision() async -> OnboardingCloudStatus {
        do {
            // CloudDocs: create the app folder first — the first touch of iCloud Drive triggers
            // the macOS consent prompt, and the probe write fails fast if consent is declined.
            if let cloudDocs = provider as? CloudDocsProvider {
                try cloudDocs.ensureAppFolder()
            }
            let state = try await manager.openWorkspace(provisionIfMissing: true)
            guard let workspace = state.workspace, state.availability == .available else {
                return .failure(reason: Self.onboardingFailureCopy(for: state.availability))
            }
            workspaceURL = workspace.rootURL
            availability = state.availability
            syncState = provider.syncState
            didProvision = state.didProvision
            missingPaths = state.missingPaths
            await reindex()
            return .success(path: Self.displayPath(workspace.rootURL))
        } catch let error as WorkspaceResolutionError {
            return .failure(reason: Self.onboardingFailureCopy(for: error))
        } catch {
            return .failure(reason: "Couldn't create the workspace folder: \(error.localizedDescription)")
        }
    }

    /// Steps 2–3 — apply an onboarding add-plan through the safe-write path (backup → atomic
    /// apply → re-index). The wizard shows the canonical row inline as its preview.
    func onboardingApply(_ plan: WritePlan) async -> String? {
        guard let workspaceURL else { return "No workspace is open yet — complete the iCloud step first." }
        do {
            let previewed = WriteService(workspaceURL: workspaceURL).preview(plan)
            _ = try WriteService(workspaceURL: workspaceURL)
                .apply(previewed, workspaceState: syncState, fileStates: [:])
            await reindex()
            return nil
        } catch {
            return String(describing: error)
        }
    }

    /// Build the Step-2 plan: append a row to `Accounts/account-groups.csv`.
    func onboardingGroupPlan(name: String, groupType: String) -> (plan: WritePlan, id: String, row: String)? {
        guard let text = readWorkspaceFile("Accounts/account-groups.csv"),
              let header = CSVRowSerializer.header(of: text) else { return nil }
        let id = "grp-" + Self.slug(name)
        let fields = ["account_group_id": id, "name": name, "group_type": groupType]
        let plan = WritePlanBuilder.add(fields: fields, to: "Accounts/account-groups.csv", fileText: text)
        return (plan, id, CSVRowSerializer.row(fields: fields, header: header))
    }

    /// Build the Step-3 plan: append a row to `Accounts/accounts.csv` linked to the Step-2 group.
    func onboardingAccountPlan(displayName: String, institution: String, accountGroup: String,
                               accountType: String, groupId: String) -> (plan: WritePlan, row: String)? {
        guard let text = readWorkspaceFile("Accounts/accounts.csv"),
              let header = CSVRowSerializer.header(of: text) else { return nil }
        let fields: [String: String] = [
            "account_id": "acct-" + Self.slug(displayName),
            "display_name": displayName,
            "institution": institution,
            "account_group": accountGroup,
            "account_type": accountType,
            "status": "active",
            "account_group_id": groupId,
        ]
        let plan = WritePlanBuilder.add(fields: fields, to: "Accounts/accounts.csv", fileText: text)
        return (plan, CSVRowSerializer.row(fields: fields, header: header))
    }

    /// All three steps done — persist completion and hand over to the shell.
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: AppConfig.onboardingCompleteKey)
        showingOnboarding = false
    }

    // MARK: - Copy / helpers

    private static func onboardingFailureCopy(for availability: WorkspaceAvailability) -> String {
        switch availability {
        case .notSignedIn:
            return "You're not signed into iCloud. Open System Settings → Apple ID, sign in, then retry."
        case .containerUnavailable:
            return "iCloud Drive is unavailable. Turn it on in System Settings → Apple ID → iCloud → Drive, then retry."
        case .missing:
            return "The workspace folder was created but required files are missing — retry to re-provision."
        case .available:
            return "Something interrupted workspace creation — please retry."
        }
    }

    private static func onboardingFailureCopy(for error: WorkspaceResolutionError) -> String {
        switch error {
        case .notSignedIn:
            return "You're not signed into iCloud. Open System Settings → Apple ID, sign in, then retry."
        case .containerUnavailable:
            return "iCloud Drive is unavailable (or access was declined). Enable iCloud Drive — and "
                 + "allow access when macOS asks — then retry."
        case .localFolderMissing:
            return "The development folder is missing. Run bootstrap-workspace, then retry."
        }
    }

    /// "~/Library/Mobile Documents/…" reads friendlier than the absolute home path.
    private static func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    /// "My Bank!" → "my-bank" + a short unique suffix (ids must be unique, FR — id conventions).
    static func slug(_ name: String) -> String {
        let lowered = name.lowercased()
        let mapped = lowered.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let collapsed = String(mapped).split(separator: "-").joined(separator: "-")
        let base = collapsed.isEmpty ? "item" : collapsed
        return "\(base)-\(UUID().uuidString.prefix(4).lowercased())"
    }
}
