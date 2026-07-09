import SwiftUI
import FinanceWorkspaceKit

// Phase 7 (008) US2 T021/T022 — the interactive per-collection reassignment picker (OOS-17 /
// FR-006). Deleting a referenced object never orphans (Round-7 locked "reassign" policy); this
// surface replaces the previous first-available-target default with an explicit user choice:
// one picker per referencing collection, "Leave unlinked" only where the FK is schema-optional,
// "Remove from list" for list-valued FKs. Apply stays disabled until every collection has a
// choice; the deleted id itself is never offered. Confirming builds ONE atomic plan
// (delete + all reassignments) through the standard write preview (DESIGN.md "modal-form").

/// Selection state for one delete-with-references decision. Kept UI-free so the apply-gating
/// and candidate rules are unit-testable (T020).
@MainActor
@Observable
final class ReassignmentModel: Identifiable {
    /// Sentinel picker values (candidate ids can never collide — ids are CSV field values).
    static let unlinkChoice = "__unlink__"
    static let unset = ""

    let id = UUID()
    let ref: SourceRef
    let rowRef: Int
    let before: String
    let deletedId: String
    let displayName: String
    let groups: [ReferenceGroup]
    private let allTargets: [String]
    /// Picker selection per group key — a candidate id or `unlinkChoice`; `unset` = no choice yet.
    var selections: [String: String] = [:]

    init(ref: SourceRef, rowRef: Int, before: String, deletedId: String,
         groups: [ReferenceGroup], targets: [String]) {
        self.ref = ref
        self.rowRef = rowRef
        self.before = before
        self.deletedId = deletedId
        self.displayName = deletedId
        self.groups = groups
        self.allTargets = targets
        for group in groups { selections[Self.key(group)] = Self.unset }
    }

    static func key(_ group: ReferenceGroup) -> String { "\(group.collection).\(group.column)" }

    /// Candidate target ids for a group — never the deleted object itself (T020).
    func candidates(for group: ReferenceGroup) -> [String] {
        allTargets.filter { $0 != deletedId }
    }

    /// Whether the group offers a "leave unlinked / remove from list" choice.
    func allowsUnlink(_ group: ReferenceGroup) -> Bool { group.nullable || group.isList }

    /// A group with no candidates and no unlink option can't be resolved — apply must block.
    func isResolvable(_ group: ReferenceGroup) -> Bool {
        !candidates(for: group).isEmpty || allowsUnlink(group)
    }

    /// The chosen target for a group, nil until the user picks (or the choice is invalid).
    func target(for group: ReferenceGroup) -> Reassignment.Target? {
        switch selections[Self.key(group)] ?? Self.unset {
        case Self.unset: return nil
        case Self.unlinkChoice: return allowsUnlink(group) ? .unlink : nil
        case let id where id == deletedId: return nil          // self-target rejected
        case let id: return .reassign(id: id)
        }
    }

    /// Apply is blocked until EVERY referencing collection has a valid choice (T020).
    var canApply: Bool {
        !groups.isEmpty && groups.allSatisfy { target(for: $0) != nil }
    }

    /// The confirmed choices, in group order (only meaningful when `canApply`).
    var reassignments: [Reassignment] {
        groups.compactMap { group in target(for: group).map { Reassignment(group: group, target: $0) } }
    }
}

struct ReassignmentPickerView: View {
    @Environment(AppState.self) private var state
    @Bindable var model: ReassignmentModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                OverlineLabel(text: "Delete \(model.displayName)")
                Text("Other records reference this one. Choose where each collection's rows "
                     + "should point before the delete is applied — everything happens in one "
                     + "atomic, backed-up write.")
                    .font(DS.Fonts.caption)
                    .foregroundStyle(DS.Colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider().overlay(DS.Colors.borderSoft)

            Form {
                ForEach(model.groups, id: \.collection) { group in
                    groupSection(group)
                }
            }
            .formStyle(.grouped)
            .font(DS.Fonts.body)

            Divider().overlay(DS.Colors.borderSoft)
            HStack {
                Spacer()
                Button("Cancel") { state.pendingReassignment = nil }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Delete & reassign…") { state.applyReassignments(model) }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canApply)
            }
            .padding(12)
        }
        .frame(width: 460, height: min(500, 220 + CGFloat(model.groups.count) * 92))
    }

    @ViewBuilder private func groupSection(_ group: ReferenceGroup) -> some View {
        Section("\(group.collection) — \(group.rows.count) row\(group.rows.count == 1 ? "" : "s") via \(group.column)") {
            Picker("Reassign to", selection: binding(for: group)) {
                Text("Choose…").tag(ReassignmentModel.unset)
                ForEach(model.candidates(for: group), id: \.self) { Text($0).tag($0) }
                if model.allowsUnlink(group) {
                    Divider()
                    Text(group.isList ? "Remove from list" : "Leave unlinked")
                        .tag(ReassignmentModel.unlinkChoice)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Reassign \(group.collection) rows referencing \(group.column)")
            if !model.isResolvable(group) {
                Text("No reassignment target exists and this reference is required — create a "
                     + "replacement first.")
                    .font(DS.Fonts.caption)
                    .foregroundStyle(DS.Colors.warn)
            }
        }
    }

    private func binding(for group: ReferenceGroup) -> Binding<String> {
        let key = ReassignmentModel.key(group)
        return Binding(get: { model.selections[key] ?? ReassignmentModel.unset },
                       set: { model.selections[key] = $0 })
    }
}
