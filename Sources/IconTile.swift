import SwiftUI

struct IconTile<Content: View>: View {
    var color: Color = .accentColor
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 46, height: 46)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}
