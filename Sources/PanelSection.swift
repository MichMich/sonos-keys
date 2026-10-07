import SwiftUI

struct PanelSection<Content: View>: View {
    var background: Color = .clear
    var padding: CGFloat = 18
    var topDivider = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(alignment: .top) {
                if topDivider {
                    Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                }
            }
    }
}
