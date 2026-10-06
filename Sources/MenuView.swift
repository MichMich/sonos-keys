import SwiftUI

struct MenuView: View {
    @ObservedObject var model: AppModel
    let openSettings: () -> Void
    let openAbout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sonos Keys").font(.headline)
            Text(model.room.isEmpty ? "Configure a Sonos room" : "\(model.modifierTitle) media keys → \(model.room)")
                .font(.caption).foregroundStyle(.secondary)
            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if model.permissionPage != nil {
                Button("Open Privacy Settings…") { model.openPermissionSettings() }
                Button("Retry media keys") { model.retryMediaKeys() }
            }
            Divider()
            Toggle("Enable Sonos keys", isOn: Binding(get: { model.enabled }, set: { _ in model.toggle() }))
                .toggleStyle(.switch)
                .disabled(model.room.isEmpty)
            Divider()
            Button("About Sonos Keys…", action: openAbout)
            HStack {
                Button("Settings…", action: openSettings)
                Spacer()
                Button("Quit") { model.quit() }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
