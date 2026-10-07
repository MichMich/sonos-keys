import SwiftUI

struct ErrorView: View {
    let title: String
    let message: String
    var actions: [ActionGroup.Action] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                IconTile(color: .orange) {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 12, weight: .semibold))
                    Text(message).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !actions.isEmpty { ActionGroup(actions: actions) }
        }
    }
}
