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
                HStack(spacing: 14) {
                    AsyncImage(url: model.track?.artworkURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ZStack {
                            Color.secondary.opacity(0.1)
                            Image(systemName: "music.note").foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        if let track = model.track {
                            Text(track.title.isEmpty ? "Unknown title" : track.title)
                                .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                            if !track.artist.isEmpty {
                                Text(track.artist).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            }
                        } else {
                            Text(model.trackError ?? (model.trackLoading ? "Loading track info…" : "No track information"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 82)
                .background(Color.black.opacity(0.2))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                }
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
                        VStack(spacing: 0) {
                            actionRow("Privacy Settings", icon: "lock.shield", action: model.openPermissionSettings)
                            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                            actionRow("Retry media keys", icon: "arrow.clockwise", action: model.retryMediaKeys)
                        }
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.05))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                }
            }

            VStack(spacing: 0) {
                actionRow("Settings", icon: "gearshape.fill", action: openSettings)
                Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                actionRow("About", icon: "info.circle.fill", action: openAbout)
                Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
                actionRow("Quit", icon: "power", action: model.quit)
            }
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(18)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
            }
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func actionRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(Color.accentColor).frame(width: 18)
                Text(title)
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
