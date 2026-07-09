import SwiftUI
import FinanceWorkspaceKit

// First-launch onboarding wizard (008 US5 / T045; DESIGN.md "onboarding-wizard" + "step-indicator",
// v1.2). One centered lg-radius card over the window bg — a floating surface, so it carries a real
// shadow — with a step-indicator header, one step visible at a time, and a ghost-Back /
// primary-Continue footer. Non-dismissable until all three steps complete (require-iCloud: there
// is no local fallback here). Steps:
//   1. Welcome & iCloud — create the dedicated workspace folder; ok/err status-chip semantics,
//      retry on failure (signed out / iCloud Drive off / consent declined).
//   2. First account group — Accounts/account-groups.csv (name + group_type).
//   3. First account — Accounts/accounts.csv, linked to the Step-2 group.
// Both writes go through the safe-write engine and show the canonical CSV row inline as the
// preview (constitution #4), with the target file path for traceability (constitution #5).

// MARK: - Wizard model

@MainActor
@Observable
final class OnboardingModel {
    enum Step: Int, CaseIterable {
        case welcome = 0, group = 1, account = 2
    }

    var step: Step = .welcome
    var cloudStatus: OnboardingCloudStatus = .pending

    // Step 2 — account group.
    var groupName = "Personal"
    var groupType = "personal"
    var createdGroupId: String?

    // Step 3 — first account.
    var accountName = ""
    var institution = ""
    var accountGroup = "checking"     // accounts.csv `account_group` enum (kind of account)
    var accountType = "personal"
    var isApplying = false
    var writeError: String?

    static let groupTypes = ["personal", "employment", "business", "custom"]
    static let accountKinds = ["checking", "savings", "credit_card", "investment", "employment", "business", "loan"]

    var groupValid: Bool { !groupName.trimmingCharacters(in: .whitespaces).isEmpty }
    var accountValid: Bool { !accountName.trimmingCharacters(in: .whitespaces).isEmpty }
}

// MARK: - Wizard container

struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var model = OnboardingModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DS.Colors.borderSoft)
            stepBody
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(EdgeInsets(top: DS.Metrics.contentPaddingV, leading: DS.Metrics.contentPaddingH,
                                    bottom: DS.Metrics.contentPaddingV, trailing: DS.Metrics.contentPaddingH))
            Divider().overlay(DS.Colors.borderSoft)
            footer
        }
        .frame(width: 520)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)   // floating surface (DESIGN.md elevation)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.windowBg)
        .interactiveDismissDisabled()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            StepIndicatorView(current: model.step.rawValue, total: OnboardingModel.Step.allCases.count)
            Text(title)
                .font(DS.Fonts.pageTitle)
                .foregroundStyle(DS.Colors.ink1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: DS.Metrics.contentPaddingV, leading: DS.Metrics.contentPaddingH,
                            bottom: 12, trailing: DS.Metrics.contentPaddingH))
    }

    private var title: String {
        switch model.step {
        case .welcome: return "Welcome to Open Finance"
        case .group:   return "Create your first account group"
        case .account: return "Add your first account"
        }
    }

    @ViewBuilder private var stepBody: some View {
        switch model.step {
        case .welcome: OnboardingWelcomeStep(model: model)
        case .group:   OnboardingGroupStep(model: model)
        case .account: OnboardingAccountStep(model: model)
        }
    }

    // MARK: Footer (ghost Back / primary Continue)

    private var footer: some View {
        HStack {
            if model.step != .welcome {
                Button("Back") { back() }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(model.isApplying)
            }
            Spacer()
            if let error = model.writeError {
                Text(error).font(DS.Fonts.caption).foregroundStyle(DS.Colors.err)
                    .lineLimit(2).frame(maxWidth: 280, alignment: .trailing)
            }
            Button(continueLabel) { Task { await advance() } }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!canContinue || model.isApplying)
        }
        .padding(EdgeInsets(top: 12, leading: DS.Metrics.contentPaddingH,
                            bottom: 12, trailing: DS.Metrics.contentPaddingH))
    }

    private var continueLabel: String {
        switch model.step {
        case .welcome: return cloudReady ? "Continue" : "Create workspace"
        case .group:   return "Create group"
        case .account: return "Create account & finish"
        }
    }

    private var cloudReady: Bool {
        if case .success = model.cloudStatus { return true }
        return false
    }

    private var canContinue: Bool {
        switch model.step {
        case .welcome: return true
        case .group:   return model.groupValid
        case .account: return model.accountValid
        }
    }

    private func back() {
        model.writeError = nil
        model.step = OnboardingModel.Step(rawValue: model.step.rawValue - 1) ?? .welcome
    }

    /// The Continue action per step. Step 1 provisions (or re-tries) before moving on; Steps 2–3
    /// apply their safe-write plan and only advance when the write lands.
    private func advance() async {
        model.writeError = nil
        switch model.step {
        case .welcome:
            if !cloudReady {
                model.isApplying = true
                model.cloudStatus = .working
                model.cloudStatus = await state.onboardingProvision()
                model.isApplying = false
            }
            if cloudReady { model.step = .group }

        case .group:
            guard let built = state.onboardingGroupPlan(name: model.groupName, groupType: model.groupType) else {
                model.writeError = "Workspace files aren't readable yet — go back and retry the iCloud step."
                return
            }
            model.isApplying = true
            let error = await state.onboardingApply(built.plan)
            model.isApplying = false
            if let error { model.writeError = error; return }
            model.createdGroupId = built.id
            model.step = .account

        case .account:
            guard let groupId = model.createdGroupId,
                  let built = state.onboardingAccountPlan(
                    displayName: model.accountName, institution: model.institution,
                    accountGroup: model.accountGroup, accountType: model.accountType,
                    groupId: groupId) else {
                model.writeError = "Workspace files aren't readable yet — go back and retry the iCloud step."
                return
            }
            model.isApplying = true
            let error = await state.onboardingApply(built.plan)
            model.isApplying = false
            if let error { model.writeError = error; return }
            state.completeOnboarding()
        }
    }
}

// MARK: - Step indicator (DESIGN.md "step-indicator")

struct StepIndicatorView: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < current ? DS.Colors.accent : DS.Colors.surfaceSunken)
                    .overlay(Circle().stroke(
                        index == current ? DS.Colors.accent : DS.Colors.border,
                        lineWidth: index == current ? 2 : 1))
                    .frame(width: 8, height: 8)
            }
            Text("Step \(current + 1) of \(total)")
                .font(DS.Fonts.caption)
                .foregroundStyle(DS.Colors.muted)
        }
    }
}

// Light + dark previews (PreviewProvider form — CLT-only box; see AppShellView note).
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView().environment(AppState()).frame(width: 900, height: 640)
            .preferredColorScheme(.light).previewDisplayName("Onboarding — light")
        OnboardingView().environment(AppState()).frame(width: 900, height: 640)
            .preferredColorScheme(.dark).previewDisplayName("Onboarding — dark")
    }
}
