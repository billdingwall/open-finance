import SwiftUI

// T004 — Panel chrome (`.panel`): panel-head (title + muted sub + right actions) over panel-body.
// 1px border on `surface`, radius DEFAULT; depth via border, never a shadow (inline surface).

struct PanelView<Content: View, Actions: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    init(title: String, subtitle: String? = nil,
         @ViewBuilder content: () -> Content,
         @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(DS.Fonts.panelTitle).foregroundStyle(DS.Colors.ink1)
                if let subtitle {
                    Text(subtitle).font(DS.Fonts.caption).foregroundStyle(DS.Colors.muted)
                }
                Spacer(minLength: DS.Metrics.unit)
                actions
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider().overlay(DS.Colors.borderSoft)
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.normal))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.normal).stroke(DS.Colors.border, lineWidth: 1))
    }
}
