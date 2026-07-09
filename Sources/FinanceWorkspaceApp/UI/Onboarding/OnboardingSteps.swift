import SwiftUI
import FinanceWorkspaceKit

// The three onboarding step bodies + shared step chrome (008 US5 T045; DESIGN.md
// "onboarding-wizard" v1.2) — split from OnboardingView for file-size hygiene. The wizard
// container, model, and step indicator live in OnboardingView.swift.

// MARK: - Step 1 · Welcome & iCloud

struct OnboardingWelcomeStep: View {
    @Environment(AppState.self) private var state
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Open Finance is a personal-finance workspace built on plain CSV and Markdown files "
                 + "you own. Your workspace lives in a dedicated folder in your iCloud Drive, so it "
                 + "syncs across your Macs and stays fully readable in Finder.")
                .font(DS.Fonts.body)
                .foregroundStyle(DS.Colors.ink2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                OverlineLabel(text: "Workspace location")
                Text(locationDescription)
                    .font(DS.Fonts.table)
                    .foregroundStyle(DS.Colors.ink3)
                statusRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.normal))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.normal).stroke(DS.Colors.borderSoft, lineWidth: 1))

            if case .failure(let reason) = model.cloudStatus {
                Text(reason)
                    .font(DS.Fonts.caption)
                    .foregroundStyle(DS.Colors.err)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var locationDescription: String {
        switch state.provider.providerKind {
        case .cloudDocs:   return "iCloud Drive › OpenFinance › Finance"
        case .iCloud:      return "iCloud › Open Finance container › Documents › Finance"
        case .localFolder: return "~/Finance-Dev/Finance (development)"
        }
    }

    @ViewBuilder private var statusRow: some View {
        switch model.cloudStatus {
        case .pending:
            StatusChip(kind: .info, label: "Not created yet")
        case .working:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Creating workspace…").font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            }
        case .success(let path):
            HStack(spacing: 8) {
                StatusChip(kind: .ok, label: "Workspace ready")
                Text(path).font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted).lineLimit(1)
            }
        case .failure:
            StatusChip(kind: .err, label: "iCloud unavailable — retry below")
        }
    }
}

// MARK: - Step 2 · First account group

struct OnboardingGroupStep: View {
    @Environment(AppState.self) private var state
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account groups organise your accounts by who they belong to — personal, an "
                 + "employer, or a business entity. Every account lives in exactly one group.")
                .font(DS.Fonts.body)
                .foregroundStyle(DS.Colors.ink2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                OnboardingField(label: "Group name") {
                    TextField("Personal", text: $model.groupName)
                        .textFieldStyle(.roundedBorder).font(DS.Fonts.body)
                }
                OnboardingField(label: "Group type") {
                    Picker("", selection: $model.groupType) {
                        ForEach(OnboardingModel.groupTypes, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu)
                    .accessibilityLabel("Group type")
                }
            }

            OnboardingWritePreview(
                filePath: "Accounts/account-groups.csv",
                row: state.onboardingGroupPlan(name: model.groupName, groupType: model.groupType)?.row)
        }
    }
}

// MARK: - Step 3 · First account

struct OnboardingAccountStep: View {
    @Environment(AppState.self) private var state
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Accounts are the master registry every other module references — transactions, "
                 + "budgets, goals, and taxes all link back to an account.")
                .font(DS.Fonts.body)
                .foregroundStyle(DS.Colors.ink2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                OnboardingField(label: "Account name") {
                    TextField("Everyday Checking", text: $model.accountName)
                        .textFieldStyle(.roundedBorder).font(DS.Fonts.body)
                }
                OnboardingField(label: "Institution (optional)") {
                    TextField("Bank name", text: $model.institution)
                        .textFieldStyle(.roundedBorder).font(DS.Fonts.body)
                }
                OnboardingField(label: "Kind of account") {
                    Picker("", selection: $model.accountGroup) {
                        ForEach(OnboardingModel.accountKinds, id: \.self) {
                            Text($0.replacingOccurrences(of: "_", with: " ")).tag($0)
                        }
                    }
                    .labelsHidden().pickerStyle(.menu)
                    .accessibilityLabel("Kind of account")
                }
            }

            OnboardingWritePreview(filePath: "Accounts/accounts.csv", row: previewRow)
        }
    }

    private var previewRow: String? {
        guard let groupId = model.createdGroupId else { return nil }
        return state.onboardingAccountPlan(
            displayName: model.accountName, institution: model.institution,
            accountGroup: model.accountGroup, accountType: model.accountType,
            groupId: groupId)?.row
    }
}

// MARK: - Shared step chrome

/// Stacked modal-field: overline label above the control (DESIGN.md "modal-form").
struct OnboardingField<Control: View>: View {
    let label: String
    @ViewBuilder var control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            OverlineLabel(text: label)
            control
        }
    }
}

/// Inline safe-write preview: the exact canonical row + target file (constitution #4/#5).
struct OnboardingWritePreview: View {
    let filePath: String
    let row: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            OverlineLabel(text: "Will append to \(filePath)")
            Text(row ?? "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DS.Colors.ink3)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(DS.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }
}
