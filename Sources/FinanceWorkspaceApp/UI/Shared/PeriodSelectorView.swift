import SwiftUI
import FinanceWorkspaceKit

// T026 — inline period selector (FR-011, DESIGN `.filter` pill): month with previous/next
// stepping, keyboard operable. Session-scoped by contract (clarify Q1) — the binding lives in
// `AppState.selections` and resets on relaunch. No global filter bar exists (FR-014).

struct PeriodSelectorView: View {
    /// "YYYY-MM"; nil = current month.
    @Binding var period: String?
    /// The current month used when `period` is nil (from the snapshot's asOfMonth).
    let currentPeriod: String

    private var effective: String { period ?? currentPeriod }

    var body: some View {
        HStack(spacing: 6) {
            stepButton(systemImage: "chevron.left", help: "Previous month") { step(-1) }
            FilterPillLabel(label: "Period", value: Format.monthName(effective), isActive: period != nil)
                .onTapGesture { period = nil }          // tap resets to "current"
                .help("Click to reset to the current month")
            stepButton(systemImage: "chevron.right", help: "Next month") { step(1) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Period selector, showing \(Format.monthName(effective))")
    }

    private func stepButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(DS.Colors.muted)
                .frame(width: 20, height: 20)
                .background(DS.Colors.surface, in: Circle())
                .overlay(Circle().stroke(DS.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func step(_ delta: Int) {
        // Use the engine's canonical period math (same calendar) — no hand-rolled rollover.
        let candidate = PeriodMath.adding(delta, to: effective)
        period = candidate == currentPeriod ? nil : candidate
    }
}

struct PeriodSelectorView_Previews: PreviewProvider {
    struct Host: View {
        @State var period: String?
        var body: some View {
            PeriodSelectorView(period: $period, currentPeriod: "2026-06")
        }
    }

    static var previews: some View {
        Host().padding().preferredColorScheme(.light).previewDisplayName("Period — light")
        Host(period: "2026-03").padding().preferredColorScheme(.dark).previewDisplayName("Period — dark")
    }
}
