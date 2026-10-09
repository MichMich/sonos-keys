import SwiftUI

struct ActionGroup: View {
    struct Action {
        let title: String
        let icon: String
        let perform: () -> Void
    }

    let actions: [Action]
    var tint: Color = .accentColor
    var background: Color = .primary.opacity(0.06)

    var body: some View {
        VStack(spacing: 0) {
            ForEach(actions.indices, id: \.self) { index in
                if index > 0 {
                    Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                }
                Button(action: actions[index].perform) {
                    HStack(spacing: 10) {
                        Image(systemName: actions[index].icon).foregroundStyle(tint).frame(width: 18)
                        Text(actions[index].title)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(background, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
