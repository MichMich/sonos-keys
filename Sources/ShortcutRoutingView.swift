import SwiftUI

struct ShortcutRoutingView: View {
    let room: String
    let audioOutput: String
    let modifier: String
    let inverted: Bool

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            row(room, shortcut: inverted ? "Media Keys" : "\(modifier) + Media Keys")
            row(audioOutput, shortcut: inverted ? "\(modifier) + Media Keys" : "Media Keys")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ destination: String, shortcut: String) -> some View {
        GridRow {
            Text(destination)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .help(destination)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(shortcut)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .gridColumnAlignment(.trailing)
        }
    }
}
