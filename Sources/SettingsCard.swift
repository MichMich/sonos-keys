import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        PanelSection(background: .primary.opacity(0.04)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundStyle(Color.accentColor)
                    Text(title).font(.system(size: 14, weight: .semibold))
                }
                content()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

struct SettingsToggleStyle: ToggleStyle {
    var checkbox = false
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            if checkbox {
                Toggle("", isOn: configuration.$isOn)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
            } else {
                Toggle("", isOn: configuration.$isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }
}
