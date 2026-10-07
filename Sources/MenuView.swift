import SwiftUI
import AppKit

struct MenuView: View {
    @ObservedObject var model: AppModel
    let openSettings: () -> Void
    let openAbout: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PanelSection {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        IconTile { Image(systemName: "hifispeaker.fill") }
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
                    if model.room.isEmpty {
                        Text("Choose a room in Settings to use your media keys.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if !model.room.isEmpty {
                PanelSection(background: .black.opacity(0.08), topDivider: true) {
                    ShortcutRoutingView(room: model.room, audioOutput: model.audioOutputName,
                                        modifier: model.modifierTitle, inverted: model.inverted)
                }
            }

            if model.showTrackInfoInMenu && model.menuVisible {
                TrackInfoView(track: model.track, emptyText: model.trackError ?? (model.trackLoading ? "Loading track info…" : "No track information"))
            }

            if let error = model.error {
                PanelSection(background: .orange.opacity(0.05), topDivider: true) {
                    ErrorView(
                        title: model.permissionPage == nil ? "Sonos Keys needs attention" : "Allow media-key access",
                        message: error,
                        actions: model.permissionPage == nil ? [] : [
                            .init(title: "Privacy Settings", icon: "lock.shield", perform: model.openPermissionSettings),
                            .init(title: "Retry media keys", icon: "arrow.clockwise", perform: model.retryMediaKeys)
                        ]
                    )
                }
            }

            PanelSection(topDivider: true) {
                ActionGroup(actions: [
                    .init(title: "Settings", icon: "gearshape.fill", perform: openSettings),
                    .init(title: "About", icon: "info.circle.fill", perform: openAbout),
                    .init(title: "Quit", icon: "power", perform: model.quit)
                ])
            }
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
