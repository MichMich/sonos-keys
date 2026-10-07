import SwiftUI
import AppKit

struct MenuView: View {
    @ObservedObject var model: AppModel
    let openSettings: () -> Void
    let openAbout: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "hifispeaker.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 46, height: 46)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.room.isEmpty ? "Choose a room" : model.room)
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                        Text("Sonos Keys").font(.system(size: 19, weight: .semibold))
                    }
                    Spacer(minLength: 0)
                    Toggle("Enable Sonos keys", isOn: Binding(get: { model.enabled }, set: { _ in model.toggle() }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(model.room.isEmpty)
                        .accessibilityLabel("Enable Sonos keys")
                }
                if !model.room.isEmpty {
                    Text(model.inverted
                         ? "Media keys → Sonos\n\(model.modifierTitle) + media keys → Mac"
                         : "Media keys → Mac\n\(model.modifierTitle) + media keys → Sonos")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Choose a room in Settings to use your media keys.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)

            if model.showTrackInfoInMenu && model.menuVisible {
                TrackInfoView(track: model.track, emptyText: model.trackError ?? (model.trackLoading ? "Loading track info…" : "No track information"))
            }

            if let error = model.error {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.orange)
                            .frame(width: 46, height: 46)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.permissionPage == nil ? "Sonos Keys needs attention" : "Allow media-key access")
                                .font(.system(size: 12, weight: .semibold))
                            Text(error).font(.system(size: 11)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if model.permissionPage != nil {
                        ActionGroup(actions: [
                            .init(title: "Privacy Settings", icon: "lock.shield", perform: model.openPermissionSettings),
                            .init(title: "Retry media keys", icon: "arrow.clockwise", perform: model.retryMediaKeys)
                        ])
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.05))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                }
            }

            ActionGroup(actions: [
                .init(title: "Settings", icon: "gearshape.fill", perform: openSettings),
                .init(title: "About", icon: "info.circle.fill", perform: openAbout),
                .init(title: "Quit", icon: "power", perform: model.quit)
            ])
            .padding(18)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
            }
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
