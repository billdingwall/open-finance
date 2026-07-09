import SwiftUI
import FinanceWorkspaceKit

// T051 — goals (FR-024): a FLAT list of goal cards with progress bars (no active/archived
// grouping — locked decision; the engine already excludes archived). Card tap → goal detail.

struct GoalsListView: View {
    @Environment(AppState.self) private var state
    let viewModel: SavingsInvestmentsViewModel

    var body: some View {
        if viewModel.goals.isEmpty {
            EmptyStateView(model: EmptyStateModel(
                systemImage: "target", title: "No savings goals yet",
                message: "Goals appear once Savings/goals.csv has rows.",
                ctaTitle: "Add goal",
                ctaEnabled: state.writesEnabled,
                ctaAction: { state.addGoal() },
                ctaDisabledReason: state.writeGateReason))
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: DS.Metrics.kpiGridGap)],
                      spacing: DS.Metrics.kpiGridGap) {
                ForEach(viewModel.goals) { goal in
                    GoalCardView(goal: goal, compact: false)
                }
            }
        }
    }
}

/// One goal card: name, progress bar, engine-projected gap and months-to-goal.
struct GoalCardView: View {
    @Environment(AppState.self) private var state
    let goal: GoalProgressProjection
    var compact: Bool

    var body: some View {
        Button {
            state.router.navigate(to: .goal(goal.goalId))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    OverlineLabel(text: goal.name)
                    Spacer()
                    if goal.isCompleteDerived {
                        TagView(kind: .ok, label: "complete")
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Format.money(goal.currentBalance)).font(DS.Fonts.kpiValue)
                        .foregroundStyle(DS.Colors.ink1)
                    Text("of \(Format.money(goal.targetAmount))")
                        .font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.muted)
                }
                ProgressBarView(value: goal.currentBalance, total: goal.targetAmount)
                if !compact {
                    HStack(spacing: 10) {
                        Text("gap \(Format.money(goal.gapToTarget))")
                            .font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.muted)
                        Text(goal.monthsToGoal.map { "\($0) mo to goal" } ?? "months to goal: \(TypedStateText.notAvailable)")
                            .font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.muted)
                        Text(goal.balanceSource == .snapshot ? "snapshot" : "ledger-derived")
                            .font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.normal))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.normal).stroke(DS.Colors.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.normal))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.name), \(Format.money(goal.currentBalance)) of \(Format.money(goal.targetAmount)). Opens goal detail.")
    }
}
