import SwiftUI

// T004 — DesignSystem base component styles (DESIGN.md §Components): status chip, tag, buttons,
// and the filter pill. All values resolve DS tokens; no literals.

// MARK: - Layout

extension View {
    /// The standard module-content gutter (DESIGN.md content-padding token: 18 top/bottom · 24
    /// sides). One definition so every module view can't drift its gutters.
    func moduleContentPadding() -> some View {
        padding(EdgeInsets(top: DS.Metrics.contentPaddingV, leading: DS.Metrics.contentPaddingH,
                           bottom: DS.Metrics.contentPaddingV, trailing: DS.Metrics.contentPaddingH))
    }
}

// MARK: - Status chip / tag semantics

/// The four status semantics (ok/warn/err/info) plus their soft backgrounds.
enum StatusKind {
    case ok, warn, err, info

    var color: Color {
        switch self {
        case .ok: return DS.Colors.ok
        case .warn: return DS.Colors.warn
        case .err: return DS.Colors.err
        case .info: return DS.Colors.info
        }
    }

    var softColor: Color {
        switch self {
        case .ok: return DS.Colors.okSoft
        case .warn: return DS.Colors.warnSoft
        case .err: return DS.Colors.errSoft
        case .info: return DS.Colors.infoSoft
        }
    }
}

/// Pill chip with a leading status dot — sync state + issue counts (`.status-chip`).
struct StatusChip: View {
    let kind: StatusKind
    let label: String
    var count: Int?

    var body: some View {
        HStack(spacing: DS.Metrics.unit) {
            Circle().fill(kind.color).frame(width: 6, height: 6)
            Text(label).font(DS.Fonts.caption)
            if let count {
                Text("\(count)").font(DS.Fonts.captionNumeric).fontWeight(.semibold)
            }
        }
        .foregroundStyle(kind.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(kind.softColor, in: Capsule())
    }
}

/// Inline record label pill (`.tag`) — e.g. provenance, `BX-` business rows.
struct TagView: View {
    let kind: StatusKind
    let label: String

    var body: some View {
        Text(label)
            .font(DS.Fonts.caption)
            .foregroundStyle(kind.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(kind.softColor, in: Capsule())
    }
}

// MARK: - Buttons (`.btn` / `.btn-primary` / `.btn-ghost`)

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Fonts.body)
            .foregroundStyle(DS.Colors.onAccent)   // WCAG AA on the accent fill in both modes (v1.3)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(DS.Colors.accent.opacity(configuration.isPressed ? 0.85 : 1),
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Fonts.body)
            .foregroundStyle(DS.Colors.ink2)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(configuration.isPressed ? DS.Colors.surfaceSunken : DS.Colors.surface,
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Colors.border, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Fonts.body)
            .foregroundStyle(DS.Colors.accentInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(configuration.isPressed ? DS.Colors.accentSoft : .clear,
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

// MARK: - Filter pill (`.filter`) — inline period/account selection only (no global filter bar)

struct FilterPillLabel: View {
    let label: String
    let value: String
    var isActive = false

    var body: some View {
        HStack(spacing: DS.Metrics.unit) {
            Text(label).font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
            Text(value).font(DS.Fonts.captionNumeric).foregroundStyle(DS.Colors.ink2)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(DS.Colors.muted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? DS.Colors.accentSoft : DS.Colors.surface, in: Capsule())
        .overlay(Capsule().stroke(isActive ? DS.Colors.accentBorder : DS.Colors.border, lineWidth: 1))
    }
}
